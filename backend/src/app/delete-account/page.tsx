"use client";
import { useState } from "react";
export default function DeleteAccount() {
  const [msg, setMsg] = useState("");
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault(); const f = new FormData(e.currentTarget);
    const res = await fetch("/api/public/delete-account", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: f.get("email"), password: f.get("password") }) });
    setMsg(res.ok ? "Your account has been deleted." : "Could not verify your credentials.");
  }
  return (<main><h1>Delete your NEAR ME account</h1>
    <p>You can delete your account inside the app (Settings → Account → Delete account) or here. Deletion removes your profile, photos, messages and credentials. Limited security and audit records may be retained for up to 90 days where required to prevent abuse or by law.</p>
    <form onSubmit={submit}><p><input name="email" type="email" placeholder="Email" required /></p><p><input name="password" type="password" placeholder="Password" required /></p><button type="submit">Delete my account</button></form>
    <p role="status">{msg}</p></main>);
}
