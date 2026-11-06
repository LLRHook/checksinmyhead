//go:build integration

package migrations

import (
	"context"
	"errors"
	"runtime"
	"testing"
)

var errMigrationOutcomeUnavailable = errors.New("migration outcome unavailable")

// observedMigrationOutcome is test-only. It retains one real producer result,
// including its original cause, independently of the activity observer's error.
// It does not turn early completion into evidence of a PostgreSQL barrier.
type observedMigrationOutcome struct {
	result        <-chan error
	received      bool
	closed        bool
	err           error
	joinAttempted bool
	joinErr       error
}

func (o *observedMigrationOutcome) capture() {
	if o.received || o.closed {
		return
	}
	select {
	case err, ok := <-o.result:
		if !ok {
			o.closed = true
			return
		}
		o.received = true
		o.err = err
	default:
	}
}

func (o *observedMigrationOutcome) join(ctx context.Context) error {
	if o.joinAttempted {
		return o.joinErr
	}
	o.joinAttempted = true
	o.capture()
	if o.received {
		return nil
	}
	if o.closed {
		o.joinErr = errMigrationOutcomeUnavailable
		return o.joinErr
	}
	select {
	case err, ok := <-o.result:
		if ok {
			o.received = true
			o.err = err
		} else {
			o.closed = true
			o.joinErr = errMigrationOutcomeUnavailable
		}
	case <-ctx.Done():
		o.joinErr = errors.Join(errMigrationOutcomeUnavailable, ctx.Err())
	}
	return o.joinErr
}

type migrationActivityObservation struct {
	barrierSeen bool
	err         error
}

func observeMigrationActivity(ctx context.Context, poll func(context.Context) (bool, error), outcome *observedMigrationOutcome) migrationActivityObservation {
	for {
		outcome.capture()
		found, err := poll(ctx)
		// The producer may finish while the real SQL observation is in flight.
		outcome.capture()
		if err != nil {
			return migrationActivityObservation{err: err}
		}
		if found {
			return migrationActivityObservation{barrierSeen: true}
		}
		if outcome.received || outcome.closed {
			return migrationActivityObservation{}
		}
		if ctx.Err() != nil {
			return migrationActivityObservation{err: ctx.Err()}
		}
		runtime.Gosched()
	}
}

// All fields are finite classifications. No SQL, raw database error, DSN,
// application/schema name or customer value is emitted by the evidence log.
type migrationObservationEvidence struct {
	BarrierSeen       bool
	ResultObserved    bool
	ResultNonNil      bool
	ResultDeadline    bool
	ResultCanceled    bool
	ResultChannelEnd  bool
	JoinAttempted     bool
	JoinUnresolved    bool
	CallerDeadline    bool
	CallerCanceled    bool
	ObserverError     bool
	ObserverDeadline  bool
	RollbackObserved  bool
	RollbackEmpty     bool
	RollbackReadError bool
}

func (o *observedMigrationOutcome) evidence(ctx context.Context, activity migrationActivityObservation) migrationObservationEvidence {
	return migrationObservationEvidence{
		BarrierSeen: activity.barrierSeen, ResultObserved: o.received,
		ResultNonNil:     o.received && o.err != nil,
		ResultDeadline:   o.received && errors.Is(o.err, context.DeadlineExceeded),
		ResultCanceled:   o.received && errors.Is(o.err, context.Canceled),
		ResultChannelEnd: o.closed, JoinAttempted: o.joinAttempted,
		JoinUnresolved:   o.joinErr != nil,
		CallerDeadline:   errors.Is(ctx.Err(), context.DeadlineExceeded),
		CallerCanceled:   errors.Is(ctx.Err(), context.Canceled),
		ObserverError:    activity.err != nil,
		ObserverDeadline: errors.Is(activity.err, context.DeadlineExceeded),
	}
}

func TestMigrationOutcomeObservation(t *testing.T) {
	t.Run("early_deadline_result_survives_missing_barrier", func(t *testing.T) {
		result := make(chan error, 1)
		original := errors.Join(errors.New("synthetic primary"), context.DeadlineExceeded)
		result <- original
		outcome := &observedMigrationOutcome{result: result}
		activity := observeMigrationActivity(context.Background(), func(context.Context) (bool, error) { return false, nil }, outcome)
		if activity.barrierSeen || activity.err != nil || !outcome.received || outcome.err != original || !errors.Is(outcome.err, context.DeadlineExceeded) {
			t.Fatal("missing barrier lost original early deadline result")
		}
		if err := outcome.join(context.Background()); err != nil {
			t.Fatal("retained result was consumed twice")
		}
		evidence := outcome.evidence(context.Background(), activity)
		if evidence.BarrierSeen || !evidence.ResultObserved || !evidence.ResultDeadline || evidence.JoinUnresolved {
			t.Fatal("early result was substituted for a witnessed barrier")
		}
	})
	t.Run("observer_error_keeps_primary_outcome", func(t *testing.T) {
		result := make(chan error, 1)
		original := errors.Join(errors.New("synthetic primary"), context.Canceled)
		observer := errors.New("synthetic observer")
		outcome := &observedMigrationOutcome{result: result}
		activity := observeMigrationActivity(context.Background(), func(context.Context) (bool, error) {
			result <- original
			return false, observer
		}, outcome)
		if activity.barrierSeen || activity.err != observer || !outcome.received || outcome.err != original || !errors.Is(outcome.err, context.Canceled) {
			t.Fatal("observer error discarded the independent producer outcome")
		}
	})
	t.Run("missing_result_remains_unresolved", func(t *testing.T) {
		result := make(chan error, 1)
		outcome := &observedMigrationOutcome{result: result}
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		if err := outcome.join(ctx); !errors.Is(err, errMigrationOutcomeUnavailable) || outcome.received || outcome.err != nil {
			t.Fatal("unreceived result was reported as a completed migration")
		}
		if !outcome.evidence(ctx, migrationActivityObservation{}).JoinUnresolved {
			t.Fatal("missing result lost its unresolved status")
		}
	})
	t.Run("closed_channel_is_not_success", func(t *testing.T) {
		result := make(chan error)
		close(result)
		outcome := &observedMigrationOutcome{result: result}
		activity := observeMigrationActivity(context.Background(), func(context.Context) (bool, error) { return false, nil }, outcome)
		if err := outcome.join(context.Background()); !errors.Is(err, errMigrationOutcomeUnavailable) || outcome.received || !outcome.closed || activity.barrierSeen {
			t.Fatal("closed result channel was accepted as a nil success")
		}
	})
	t.Run("barrier_and_single_receive_preserve_original_cause", func(t *testing.T) {
		result := make(chan error, 2)
		original := errors.Join(errors.New("synthetic primary"), context.DeadlineExceeded)
		secondary := errors.New("must remain queued")
		outcome := &observedMigrationOutcome{result: result}
		activity := observeMigrationActivity(context.Background(), func(context.Context) (bool, error) { return true, nil }, outcome)
		result <- original
		result <- secondary
		if err := outcome.join(context.Background()); err != nil {
			t.Fatal("healthy witnessed path did not join")
		}
		outcome.capture()
		if err := outcome.join(context.Background()); err != nil || !activity.barrierSeen || activity.err != nil || outcome.err != original || len(result) != 1 || <-result != secondary {
			t.Fatal("healthy path lost original cause or consumed another result")
		}
	})
}
