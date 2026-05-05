import { redirect } from 'next/navigation';

// Root path redirects to the dashboard.
// Middleware handles auth — unauthenticated users are sent to Auth0 login.
export default function Home() {
  redirect('/dashboard');
}
