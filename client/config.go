package client

import (
	"gopkg.in/yaml.v2"
	"heckel.io/ntfy/v2/log"
	"os"
)

const (
	// DefaultBaseURL is the base URL used to expand short topic names
	DefaultBaseURL = "https://ntfy.sh"
)

// DefaultConfigFile is the default path to the client config file (set in config_*.go)
var DefaultConfigFile string

// Config is the config struct for a Client
type Config struct {
	DefaultHost     string      `yaml:"default-host"`
	DefaultUser     string      `yaml:"default-user"`
	DefaultPassword *string     `yaml:"default-password"`
	DefaultToken    string      `yaml:"default-token"`
	DefaultCommand  string      `yaml:"default-command"`
	Subscribe       []Subscribe `yaml:"subscribe"`

	// CertFile is the path to a PKCS#12 (.p12) file used for mTLS client authentication.
	// CertPassword is the password for the PKCS#12 file (may be empty).
	CertFile     string `yaml:"cert-file"`
	CertPassword string `yaml:"cert-password"`
}

// Subscribe is the struct for a Subscription within Config
type Subscribe struct {
	Topic    string            `yaml:"topic"`
	User     *string           `yaml:"user"`
	Password *string           `yaml:"password"`
	Token    *string           `yaml:"token"`
	Command  string            `yaml:"command"`
	If       map[string]string `yaml:"if"`
}

// NewConfig creates a new Config struct for a Client
func NewConfig() *Config {
	return &Config{
		DefaultHost:     DefaultBaseURL,
		DefaultUser:     "",
		DefaultPassword: nil,
		DefaultToken:    "",
		DefaultCommand:  "",
		Subscribe:       nil,
		CertFile:        "",
		CertPassword:    "",
	}
}

// LoadConfig loads the Client config from a yaml file
func LoadConfig(filename string) (*Config, error) {
	log.Debug("Loading client config from %s", filename)
	b, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	c := NewConfig()
	if err := yaml.Unmarshal(b, c); err != nil {
		return nil, err
	}
	return c, nil
}
