'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

export default function Header() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      if (window.scrollY > 20) {
        setIsScrolled(true);
      } else {
        setIsScrolled(false);
      }
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header 
      className={`fixed w-full top-0 z-50 transition-all duration-500 ${
        isScrolled 
          ? 'py-3 backdrop-blur-lg bg-white/80 dark:bg-black/80 shadow-sm' 
          : 'py-5 bg-transparent'
      }`}
    >
      <div className="container-custom flex justify-between items-center">
        <Link href="/" className="flex items-center text-[var(--accent)] dark:text-white font-semibold text-xl">
          <i className="fas fa-receipt text-[var(--primary)] mr-2"></i>
          <span>Checkmate</span>
        </Link>
        
        <nav className="hidden md:flex items-center space-x-8">
          <a href="#features" className="header-link text-sm font-medium">Features</a>
          <a href="#privacy" className="header-link text-sm font-medium">Privacy</a>
          <a href="#how-it-works" className="header-link text-sm font-medium">How It Works</a>
          <a href="#download" className="btn-primary text-xs py-2.5 px-5">Download</a>
        </nav>
        
        <div className="md:hidden">
          <button 
            onClick={() => setIsMenuOpen(!isMenuOpen)}
            className="text-[var(--accent)] dark:text-white text-xl focus:outline-none"
            aria-label="Toggle menu"
          >
            <i className={isMenuOpen ? "fas fa-times" : "fas fa-bars"}></i>
          </button>
        </div>
      </div>
      
      {/* Mobile menu */}
      {isMenuOpen && (
        <div className="md:hidden absolute top-full left-0 w-full backdrop-blur-xl bg-white/90 dark:bg-black/90 shadow-lg py-6 px-6 animated">
          <nav className="flex flex-col space-y-6">
            <a href="#features" onClick={() => setIsMenuOpen(false)} className="text-[var(--accent)] dark:text-white font-medium block py-2">
              Features
            </a>
            <a href="#privacy" onClick={() => setIsMenuOpen(false)} className="text-[var(--accent)] dark:text-white font-medium block py-2">
              Privacy
            </a>
            <a href="#how-it-works" onClick={() => setIsMenuOpen(false)} className="text-[var(--accent)] dark:text-white font-medium block py-2">
              How It Works
            </a>
            <a href="#download" onClick={() => setIsMenuOpen(false)} className="btn-primary inline-block text-center">
              Download
            </a>
          </nav>
        </div>
      )}
    </header>
  );
}