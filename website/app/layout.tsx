import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "888Play Admin",
  description: "888Play admin dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en"><body>{children}</body></html>
  );
}
