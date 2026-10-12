package config

import "os"

const defaultAppDomain = "https://billingtonapp.vercel.app"

func AppDomain() string {
	if domain := os.Getenv("APP_DOMAIN"); domain != "" {
		return domain
	}
	return defaultAppDomain
}
