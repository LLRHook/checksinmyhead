import type { NextConfig } from "next";

const apiConnectSources = new Set(["https://billington-api.onrender.com"]);
try {
  const configuredApiUrl = new URL(process.env.NEXT_PUBLIC_API_URL ?? "");
  if (["http:", "https:"].includes(configuredApiUrl.protocol)) {
    apiConnectSources.add(configuredApiUrl.origin);
  }
} catch {
  // The API client uses its documented default when no valid URL is set.
}

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "billington-api.onrender.com",
      },
      {
        protocol: "http",
        hostname: "localhost",
        port: "8080",
      },
    ],
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: https:",
              "font-src 'self'",
              `connect-src 'self' ${[...apiConnectSources].join(" ")}`,
              "frame-ancestors 'none'",
            ].join("; "),
          },
        ],
      },
    ];
  },
};

export default nextConfig;
