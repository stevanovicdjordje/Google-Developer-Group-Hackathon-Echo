package extract

import (
	"archive/zip"
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/agenda"
)

func zipOf(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, body := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = w.Write([]byte(body))
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

// A minimal XLSX like Excel writes it: shared strings, a time as a fraction of a day.
func xlsx(t *testing.T) []byte {
	return zipOf(t, map[string]string{
		"[Content_Types].xml": `<Types/>`,
		"xl/workbook.xml":     `<workbook><sheets><sheet name="Agenda" sheetId="1"/></sheets></workbook>`,
		"xl/sharedStrings.xml": `<sst><si><t>Naslov</t></si><si><t>Sala</t></si><si><t>Početak</t></si><si><t>Kraj</t></si><si><t>Predavač</t></si>` +
			`<si><r><t>On-device </t></r><r><t>AI</t></r></si><si><t>Glavna sala</t></si><si><t>Mara Ilić</t></si></sst>`,
		"xl/worksheets/sheet1.xml": `<worksheet><sheetData>` +
			`<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c></row>` +
			`<row r="2"><c r="A2" t="s"><v>5</v></c><c r="B2" t="s"><v>6</v></c><c r="C2"><v>0.41666666666666669</v></c><c r="D2"><v>0.44791666666666669</v></c><c r="E2" t="s"><v>7</v></c></row>` +
			`<row r="3"><c r="A3" t="inlineStr"><is><t>Ručak</t></is></c><c r="C3" t="inlineStr"><is><t>12:30</t></is></c><c r="D3" t="inlineStr"><is><t>13:30</t></is></c></row>` +
			`</sheetData></worksheet>`,
	})
}

func TestSniff(t *testing.T) {
	cases := []struct {
		name string
		data []byte
		kind string
	}{
		{"a.pdf", []byte("%PDF-1.7 ..."), KindPDF},
		{"a.png", []byte("\x89PNG\r\n\x1a\n0000"), KindImage},
		{"a.xlsx", xlsx(t), KindSpreadsheet},
		{"a.docx", zipOf(t, map[string]string{"word/document.xml": "<w:document/>"}), KindDOCX},
		{"a.csv", []byte("a,b\n1,2\n"), KindCSV},
		{"notes.txt", []byte("Keynote at 10:00"), KindText},
	}
	for _, c := range cases {
		f, err := Sniff(c.name, c.data)
		if err != nil || f.Kind != c.kind {
			t.Errorf("%s: kind %q err %v", c.name, f.Kind, err)
		}
	}
	// The extension doesn't make a file a PDF; a random zip isn't accepted.
	for _, data := range [][]byte{[]byte("MZ\x90\x00binary\x00\x01"), zipOf(t, map[string]string{"x.txt": "x"})} {
		if _, err := Sniff("agenda.pdf", data); err == nil {
			t.Errorf("accepted %q", data[:4])
		}
	}
}

func TestXLSXOffline(t *testing.T) {
	f, _ := Sniff("agenda.xlsx", xlsx(t))
	ex := &Extractor{Now: func() time.Time { return time.Date(2026, 10, 11, 0, 0, 0, 0, time.UTC) }}
	res, err := ex.Extract(context.Background(), []File{f})
	if err != nil {
		t.Fatal(err)
	}
	s := res.Fields.Sessions
	if len(s) != 2 || res.Model != OfflineModel {
		t.Fatalf("%+v", res)
	}
	if s[0].Title != "On-device AI" || s[0].Stage != "Glavna sala" || s[0].Start != "10:00" || s[0].End != "10:45" ||
		len(s[0].Speakers) != 1 || s[0].Speakers[0].Name != "Mara Ilić" {
		t.Fatalf("keynote %+v", s[0])
	}
	if !s[1].IsBreak || s[1].Start != "12:30" {
		t.Fatalf("lunch %+v", s[1])
	}
	text, _ := Text(f)
	if !strings.Contains(text, "On-device AI\tGlavna sala\t10:00\t10:45\tMara Ilić") {
		t.Fatalf("text %q", text)
	}
}

func TestDOCXText(t *testing.T) {
	data := zipOf(t, map[string]string{"word/document.xml": `<w:document xmlns:w="w"><w:body>` +
		`<w:p><w:r><w:t>DevFest Belgrade 2026</w:t></w:r></w:p>` +
		`<w:p><w:r><w:t>10:00</w:t></w:r><w:r><w:tab/><w:t>Keynote</w:t></w:r></w:p></w:body></w:document>`})
	f, _ := Sniff("a.docx", data)
	text, err := Text(f)
	if err != nil || text != "DevFest Belgrade 2026\n10:00\tKeynote\n" {
		t.Fatalf("%q %v", text, err)
	}
}

func TestSplitNamesAndRoles(t *testing.T) {
	names := splitNames("Sara Đorđević & Petar Vuković (CTO, Orbita); Ana i Ivan")
	want := []string{"Sara Đorđević", "Petar Vuković (CTO, Orbita)", "Ana", "Ivan"}
	if strings.Join(names, "|") != strings.Join(want, "|") {
		t.Fatalf("%q", names)
	}
	if n, r := splitRole("Petar Vuković (CTO, Orbita)"); n != "Petar Vuković" || r != "CTO, Orbita" {
		t.Fatal(n, r)
	}
	if d := parseDay("11.10.", 2026); d != "2026-10-11" {
		t.Fatal(d)
	}
}

// The demo upload files (scripts/demo_files.py) must work without a model.
type Session = agenda.Session

func TestDemoFilesOffline(t *testing.T) {
	var files []File
	for _, name := range []string{"devfest-agenda-final-v3.pdf", "speakers.xlsx", "devfest-agenda.csv"} {
		data, err := os.ReadFile(filepath.Join("..", "..", "demo", name))
		if err != nil {
			t.Fatal(err)
		}
		f, err := Sniff(name, data)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		files = append(files, f)
	}
	res, err := (&Extractor{}).Extract(context.Background(), files)
	if err != nil || res.Model != OfflineModel {
		t.Fatal(res, err)
	}
	s := res.Fields.Sessions
	if len(s) != 7 || res.Fields.StartDate != "2026-10-11" {
		t.Fatalf("%d sessions, start %s", len(s), res.Fields.StartDate)
	}
	var workshop Session
	for _, x := range s {
		if x.Title == "Designing for crowded rooms" {
			workshop = x
		}
	}
	if workshop.Stage != "" || len(workshop.Speakers) != 1 || workshop.Speakers[0].Title != "Product Designer, Kvadrat" {
		t.Fatalf("workshop %+v", workshop)
	}
	if len(res.Fields.Speakers) != 6 {
		t.Fatalf("speakers %+v", res.Fields.Speakers)
	}
}
