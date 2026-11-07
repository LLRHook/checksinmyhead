// Package startup is the single CLI contract for both maintained service binaries.
package startup

import (
	"backend/migrations"
	"errors"
	"flag"
	"io"
)

type Options struct {
	SchemaMode  migrations.Mode
	MigrateOnly bool
	Healthcheck bool
}

func Parse(args []string) (Options, error) {
	var o Options
	flags := flag.NewFlagSet("service", flag.ContinueOnError)
	flags.SetOutput(io.Discard) // flag errors may contain hostile raw values.
	mode := flags.String("schema-mode", string(migrations.Apply), "apply or verify schema before serving")
	flags.BoolVar(&o.MigrateOnly, "migrate-only", false, "apply migrations and exit without serving")
	flags.BoolVar(&o.Healthcheck, "healthcheck", false, "probe the local service and exit")
	err := flags.Parse(args)
	healthSelected := false
	flags.Visit(func(f *flag.Flag) {
		if f.Name == "healthcheck" {
			healthSelected = true
		}
	})
	o.SchemaMode = migrations.Mode(*mode)
	if err != nil || flags.NArg() != 0 || o.SchemaMode != migrations.Apply && o.SchemaMode != migrations.Verify || o.MigrateOnly && o.SchemaMode != migrations.Apply || healthSelected && (len(args) != 1 || !o.Healthcheck) {
		return Options{}, errors.New("invalid service arguments")
	}
	return o, nil
}
