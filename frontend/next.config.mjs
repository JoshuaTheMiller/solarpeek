import nextPwa from 'next-pwa';

const withPWA = nextPwa({
  dest: 'public',
  register: true,
  skipWaiting: true,
  disable: process.env.NODE_ENV === 'development',
});

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Forward to Rails API — avoids CORS issues in dev when calling from browser
  async rewrites() {
    return [];
  },
  // Strict mode helps catch React issues early
  reactStrictMode: true,
};

export default withPWA(nextConfig);