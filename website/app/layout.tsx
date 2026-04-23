import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "8PartyPlay Admin",
  description: "8PartyPlay admin dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en"><body>{children}</body></html>
  );
}
