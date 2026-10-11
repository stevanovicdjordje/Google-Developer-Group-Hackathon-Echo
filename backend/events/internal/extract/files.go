// Package extract turns uploaded organizer files into an event draft: a
// Gemini model for anything (PDF, images, free text), and a deterministic
// table reader for spreadsheets/CSV that works without a model.
package extract

import (
	"archive/zip"
	"bytes"
	"encoding/csv"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path"
	"strconv"
	"strings"
	"unicode/utf8"
)

// Kinds of accepted files (contract SourceFile.type).
const (
	KindPDF         = "pdf"
	KindImage       = "image"
	KindSpreadsheet = "spreadsheet"
	KindCSV         = "csv"
	KindText        = "text"
	KindDOCX        = "docx"
)

// File is one uploaded file, sniffed and accepted.
type File struct {
	Name string
	Kind string
	Mime string // for PDF and images, sent to the model as is
	Data []byte
}

// ErrUnsupported is returned by Sniff for files that aren't one of the kinds.
var ErrUnsupported = errors.New("unsupported file type")

// Sniff decides the kind by content (and the extension only to tell CSV from
// plain text). It never trusts the client's Content-Type.
func Sniff(name string, data []byte) (File, error) {
	f := File{Name: name, Data: data}
	ext := strings.ToLower(path.Ext(name))
	switch mime := http.DetectContentType(data); {
	case bytes.HasPrefix(data, []byte("%PDF-")):
		f.Kind, f.Mime = KindPDF, "application/pdf"
	case mime == "image/png" || mime == "image/jpeg" || mime == "image/webp":
		f.Kind, f.Mime = KindImage, mime
	case bytes.HasPrefix(data, []byte("PK\x03\x04")):
		zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
		if err != nil {
			return f, ErrUnsupported
		}
		for _, zf := range zr.File {
			switch zf.Name {
			case "xl/workbook.xml":
				f.Kind = KindSpreadsheet
			case "word/document.xml":
				f.Kind = KindDOCX
			}
		}
		if f.Kind == "" {
			return f, ErrUnsupported
		}
	case strings.HasPrefix(mime, "text/plain") && utf8.Valid(data):
		f.Kind = KindText
		if ext == ".csv" || ext == ".tsv" {
			f.Kind = KindCSV
		}
	default:
		return f, ErrUnsupported
	}
	return f, nil
}

// Table is a sheet (or a CSV file) as rows of trimmed cells.
type Table struct {
	Name string
	Rows [][]string
}

// maxCells bounds what is read from one spreadsheet (zip bombs, huge sheets).
const maxCells = 50000

// Tables reads the rows of a CSV or XLSX file; nil for other kinds.
func Tables(f File) ([]Table, error) {
	switch f.Kind {
	case KindCSV:
		r := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(f.Data, []byte("\xef\xbb\xbf"))))
		r.FieldsPerRecord = -1
		r.LazyQuotes = true
		first, _, _ := strings.Cut(string(f.Data), "\n")
		if strings.Count(first, ";") > strings.Count(first, ",") {
			r.Comma = ';'
		} else if strings.Count(first, "\t") > strings.Count(first, ",") {
			r.Comma = '\t'
		}
		rows, err := r.ReadAll()
		if err != nil {
			return nil, fmt.Errorf("read csv: %w", err)
		}
		return []Table{{Name: f.Name, Rows: trimRows(rows)}}, nil
	case KindSpreadsheet:
		return readXLSX(f.Data)
	}
	return nil, nil
}

// Text renders a file as plain text for the model (spreadsheets as
// tab-separated rows, DOCX paragraphs); "" for PDF and images.
func Text(f File) (string, error) {
	switch f.Kind {
	case KindText, KindCSV:
		return string(f.Data), nil
	case KindSpreadsheet:
		tables, err := readXLSX(f.Data)
		if err != nil {
			return "", err
		}
		var sb strings.Builder
		for _, t := range tables {
			fmt.Fprintf(&sb, "Sheet %q:\n", t.Name)
			for _, row := range t.Rows {
				sb.WriteString(strings.Join(row, "\t"))
				sb.WriteByte('\n')
			}
		}
		return sb.String(), nil
	case KindDOCX:
		return readDOCX(f.Data)
	}
	return "", nil
}

func trimRows(rows [][]string) [][]string {
	out := make([][]string, 0, len(rows))
	for _, row := range rows {
		empty := true
		for i := range row {
			row[i] = strings.TrimSpace(row[i])
			empty = empty && row[i] == ""
		}
		if !empty {
			out = append(out, row)
		}
	}
	return out
}

func zipFile(zr *zip.Reader, name string, limit int64) ([]byte, error) {
	for _, zf := range zr.File {
		if zf.Name == name {
			rc, err := zf.Open()
			if err != nil {
				return nil, err
			}
			defer rc.Close()
			return io.ReadAll(io.LimitReader(rc, limit))
		}
	}
	return nil, nil
}

// readXLSX is a minimal reader: sheet names, shared and inline strings,
// numbers (Excel times like 0.4166 become "10:00"). Formulas use their
// cached value.
func readXLSX(data []byte) ([]Table, error) {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, fmt.Errorf("open xlsx: %w", err)
	}
	const limit = 8 << 20
	var shared []string
	if raw, err := zipFile(zr, "xl/sharedStrings.xml", limit); err == nil && raw != nil {
		var sst struct {
			SI []struct {
				T string `xml:"t"`
				R []struct {
					T string `xml:"t"`
				} `xml:"r"`
			} `xml:"si"`
		}
		if err := xml.Unmarshal(raw, &sst); err != nil {
			return nil, fmt.Errorf("xlsx shared strings: %w", err)
		}
		for _, si := range sst.SI {
			s := si.T
			for _, r := range si.R {
				s += r.T
			}
			shared = append(shared, s)
		}
	}
	// Sheet names in workbook order; sheet files are sheet1.xml, sheet2.xml…
	// in the same order for files written by Excel, Sheets and LibreOffice.
	var wb struct {
		Sheets []struct {
			Name string `xml:"name,attr"`
		} `xml:"sheets>sheet"`
	}
	raw, err := zipFile(zr, "xl/workbook.xml", limit)
	if err != nil || xml.Unmarshal(raw, &wb) != nil {
		return nil, fmt.Errorf("xlsx workbook: unreadable")
	}
	cells := 0
	var tables []Table
	for i, sh := range wb.Sheets {
		raw, err := zipFile(zr, fmt.Sprintf("xl/worksheets/sheet%d.xml", i+1), limit)
		if err != nil || raw == nil {
			continue
		}
		var ws struct {
			Rows []struct {
				C []struct {
					R  string `xml:"r,attr"`
					T  string `xml:"t,attr"`
					V  string `xml:"v"`
					IS struct {
						T string `xml:"t"`
					} `xml:"is"`
				} `xml:"c"`
			} `xml:"sheetData>row"`
		}
		if err := xml.Unmarshal(raw, &ws); err != nil {
			return nil, fmt.Errorf("xlsx sheet %q: %w", sh.Name, err)
		}
		t := Table{Name: sh.Name}
		for _, row := range ws.Rows {
			var out []string
			for _, c := range row.C {
				if cells++; cells > maxCells {
					return nil, fmt.Errorf("xlsx: more than %d cells", maxCells)
				}
				col := colIndex(c.R)
				for col >= 0 && len(out) < col && len(out) < 200 {
					out = append(out, "")
				}
				var v string
				switch c.T {
				case "s":
					if n, err := strconv.Atoi(c.V); err == nil && n >= 0 && n < len(shared) {
						v = shared[n]
					}
				case "inlineStr":
					v = c.IS.T
				default:
					v = excelNumber(c.V)
				}
				out = append(out, strings.TrimSpace(v))
			}
			t.Rows = append(t.Rows, out)
		}
		t.Rows = trimRows(t.Rows)
		tables = append(tables, t)
	}
	return tables, nil
}

// colIndex turns "C7" into 2; -1 if there is no reference.
func colIndex(ref string) int {
	n := 0
	for _, r := range ref {
		if r < 'A' || r > 'Z' {
			break
		}
		n = n*26 + int(r-'A'+1)
	}
	return n - 1
}

// excelNumber shows a fraction of a day (an Excel time) as HH:mm, and other
// numbers as written.
func excelNumber(v string) string {
	f, err := strconv.ParseFloat(v, 64)
	if err != nil || f <= 0 || f >= 1 || strings.Count(v, ".") != 1 {
		return v
	}
	mins := int(f*24*60 + 0.5)
	return fmt.Sprintf("%02d:%02d", mins/60, mins%60)
}

// readDOCX returns the document's paragraphs, one per line.
func readDOCX(data []byte) (string, error) {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("open docx: %w", err)
	}
	raw, err := zipFile(zr, "word/document.xml", 8<<20)
	if err != nil || raw == nil {
		return "", fmt.Errorf("docx: no document")
	}
	dec := xml.NewDecoder(bytes.NewReader(raw))
	var sb strings.Builder
	inText := false
	for {
		tok, err := dec.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", fmt.Errorf("docx: %w", err)
		}
		switch t := tok.(type) {
		case xml.StartElement:
			switch t.Name.Local {
			case "t":
				inText = true
			case "tab":
				sb.WriteByte('\t')
			case "br":
				sb.WriteByte('\n')
			}
		case xml.EndElement:
			switch t.Name.Local {
			case "t":
				inText = false
			case "p":
				sb.WriteByte('\n')
			case "tc":
				sb.WriteByte('\t')
			}
		case xml.CharData:
			if inText {
				sb.Write(t)
			}
		}
	}
	return sb.String(), nil
}
