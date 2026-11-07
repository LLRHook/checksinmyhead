import { ImageResponse } from "next/og";

export const dynamic = "force-static";

export function GET() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: "72px",
        background: "#f5f5f7",
        color: "#1d1d1f",
        borderTop: "16px solid #328983",
      }}
    >
      <div style={{ display: "flex", fontSize: 36, fontWeight: 700 }}>
        Billington
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
        <div
          style={{
            display: "flex",
            fontSize: 76,
            fontWeight: 700,
            letterSpacing: "-3px",
          }}
        >
          Receipt splitting.
        </div>
        <div style={{ display: "flex", fontSize: 52, color: "#2a736e" }}>
          Without an account.
        </div>
      </div>
      <div style={{ display: "flex", fontSize: 24 }}>Scan. Review. Share.</div>
    </div>,
    { width: 1200, height: 630 },
  );
}
