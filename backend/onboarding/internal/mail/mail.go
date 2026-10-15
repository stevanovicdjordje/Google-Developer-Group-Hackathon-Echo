// Package mail abstracts outgoing email. The only implementation for now logs
// the message; a real provider can be added behind the same interface.
package mail

import (
	"context"
	"log"
)

type Invitation struct {
	To         string
	EventTitle string
	Link       string
}

type Sender interface {
	SendInvitation(ctx context.Context, msg Invitation) error
}

// LogSender writes the invitation link to the server log. The organizer also
// sees every link in the UI and can copy it.
type LogSender struct{}

func (LogSender) SendInvitation(_ context.Context, msg Invitation) error {
	log.Printf("mail: invitation to %s for %q: %s", msg.To, msg.EventTitle, msg.Link)
	return nil
}
