// Root layout — Server Component. Client-side providers are isolated in
// app/providers.tsx to preserve React Server Component support in pages.
import type { Metadata } from 'next';
import Providers from './providers';

export const metadata: Metadata = {
  title:       'SolarPeak',
  description: 'Historical solar generation data dashboard',
  manifest: '/manifest.webmanifest',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'SolarPeak',
  },
  icons: {
    icon: [
      { url: '/icons/icon-192.svg', type: 'image/svg+xml' },
      { url: '/icons/icon-512.svg', type: 'image/svg+xml' },
    ],
    apple: [{ url: '/icons/apple-touch-icon.svg', type: 'image/svg+xml' }],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}
