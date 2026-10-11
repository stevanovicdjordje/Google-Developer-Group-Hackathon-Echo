// Package reports computes the post-event report ("ukupan utisak").
package reports

import (
	"sort"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

type Bucket struct {
	Stars int
	Count int
	Share float64 // 0..1 of all reviews
}

type SessionScore struct {
	Session  events.Session
	ZoneName string
	Avg      float64
	Count    int
}

type Comment struct {
	Author string // "" when the review is anonymous
	Rating int
	Text   string
	At     time.Time
}

type Report struct {
	Event events.Event

	Invited, Accepted, Declined, Expired, Pending int
	AcceptanceRate                                float64 // accepted / invited

	Reviews                      int
	ResponseRate                 float64 // reviews / accepted
	AvgRating                    float64
	Distribution                 []Bucket // 5 stars first
	PositiveShare, NegativeShare float64  // share of 4-5 and 1-2 ratings

	Sessions []SessionScore // rated sessions best first, then unrated
	Comments []Comment
}

type Input struct {
	Event       events.Event
	Invitations []invitations.Invitation
	Reviews     []reviews.WithAuthor
	Sessions    []events.Session
	ZoneNames   map[string]string
	Now         time.Time
}

func ratio(a, b int) float64 {
	if b == 0 {
		return 0
	}
	return float64(a) / float64(b)
}

// Compute aggregates raw data. It never exposes the author of an anonymous review.
func Compute(in Input) Report {
	rep := Report{Event: in.Event, Invited: len(in.Invitations)}
	for _, inv := range in.Invitations {
		switch inv.Effective(in.Event, in.Now) {
		case invitations.StatusAccepted:
			rep.Accepted++
		case invitations.StatusDeclined:
			rep.Declined++
		case invitations.StatusExpired:
			rep.Expired++
		default:
			rep.Pending++
		}
	}
	rep.AcceptanceRate = ratio(rep.Accepted, rep.Invited)

	counts := [6]int{}
	sum := 0
	for _, rv := range in.Reviews {
		counts[rv.Rating]++
		sum += rv.Rating
		if rv.Comment != "" {
			c := Comment{Rating: rv.Rating, Text: rv.Comment, At: rv.UpdatedAt}
			if !rv.Anonymous {
				c.Author = rv.AuthorName
			}
			rep.Comments = append(rep.Comments, c)
		}
	}
	rep.Reviews = len(in.Reviews)
	rep.ResponseRate = ratio(rep.Reviews, rep.Accepted)
	rep.AvgRating = ratio(sum, rep.Reviews)
	for s := 5; s >= 1; s-- {
		rep.Distribution = append(rep.Distribution, Bucket{Stars: s, Count: counts[s], Share: ratio(counts[s], rep.Reviews)})
	}
	rep.PositiveShare = ratio(counts[4]+counts[5], rep.Reviews)
	rep.NegativeShare = ratio(counts[1]+counts[2], rep.Reviews)

	sessSum, sessCount := map[string]int{}, map[string]int{}
	for _, rv := range in.Reviews {
		for sid, n := range rv.SessionRatings {
			sessSum[sid] += n
			sessCount[sid]++
		}
	}
	for _, s := range in.Sessions {
		rep.Sessions = append(rep.Sessions, SessionScore{Session: s, ZoneName: in.ZoneNames[s.ZoneID],
			Count: sessCount[s.ID], Avg: ratio(sessSum[s.ID], sessCount[s.ID])})
	}
	sort.SliceStable(rep.Sessions, func(i, j int) bool {
		a, b := rep.Sessions[i], rep.Sessions[j]
		if (a.Count == 0) != (b.Count == 0) {
			return a.Count > 0
		}
		if a.Avg != b.Avg {
			return a.Avg > b.Avg
		}
		return a.Count > b.Count
	})
	sort.SliceStable(rep.Comments, func(i, j int) bool { return rep.Comments[i].At.After(rep.Comments[j].At) })
	return rep
}

// Rated returns only sessions that received at least one rating.
func (r Report) Rated() []SessionScore {
	var out []SessionScore
	for _, s := range r.Sessions {
		if s.Count > 0 {
			out = append(out, s)
		}
	}
	return out
}
