import Header from '../components/Header';
import Hero from '../components/Hero';
import Features from '../components/Features';
import Privacy from '../components/Privacy';
import HowItWorks from '../components/HowItWorks';
import Download from '../components/Download';
import Footer from '../components/Footer';

export default function Home() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <Features />
        <Privacy />
        <HowItWorks />
        <Download />
      </main>
      <Footer />
    </>
  );
}