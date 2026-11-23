export const metadata = { title: "NEAR ME" };
export default function Root({ children }: { children: React.ReactNode }) {
  return (<html lang="en"><body style={{ fontFamily: "system-ui", maxWidth: 760, margin: "40px auto", padding: "0 16px", lineHeight: 1.6 }}>{children}</body></html>);
}
