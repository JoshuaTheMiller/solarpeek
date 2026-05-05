// Root layout — Server Component. Client-side providers are isolated in
// app/providers.tsx to preserve React Server Component support in pages.
import type { Metadata } from 'next';
import Providers from './providers';

export const metadata: Metadata = {
  title:       'SolarPeak',
  description: 'Historical solar generation data dashboard',
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
