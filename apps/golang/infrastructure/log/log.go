package log

import (
	"os"

	log "github.com/sirupsen/logrus"
)

func Setup() {
	// Adds caller method
	log.SetReportCaller(true)
	// Log as JSON instead of the default ASCII formatter.
	log.SetFormatter(&log.JSONFormatter{})
	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)
	// Only log the warning severity or above.
	log.SetLevel(log.InfoLevel)

}
