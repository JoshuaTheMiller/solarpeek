/** @type {import('next').NextConfig} */
const nextConfig = {
  // Forward to Rails API — avoids CORS issues in dev when calling from browser
  async rewrites() {
    return [];
  },
  // Strict mode helps catch React issues early
  reactStrictMode: true,
};

export default nextConfig;