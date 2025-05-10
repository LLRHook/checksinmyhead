'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

interface FooterLinkProps {
  href: string;
  text: string;
}

function FooterLink({ href, text }: FooterLinkProps) {
  return (
    <Link 
      href={href}
      className="text-[var(--text-secondary)] hover:text-[var(--primary)] transition-colors text-sm"
    >
      {text}
    </Link>
  );
}

interface FooterColumnProps {
  title: string;
  links: {
    text: string;
    href: string;
  }[];
}

function FooterColumn({ title, links }: FooterColumnProps) {
  return (
    <div>
      <h3 className="text-base font-semibold mb-6 text-[var(--accent)] dark:text-white">{title}</h3>
      <ul className="space-y-4">
        {links.map((link, index) => (
          <li key={index}>
            <FooterLink href={link.href} text={link.text} />
          </li>
        ))}
      </ul>
    </div>
  );
}

export default function Footer() {
  const [year, setYear] = useState('');
  
  useEffect(() => {
    setYear(new Date().getFullYear().toString());
  }, []);
  
  const columns: FooterColumnProps[] = [
    {
      title: "Checkmate",
      links: [
        { text: "Features", href: "#features" },
        { text: "Privacy", href: "#privacy" },
        { text: "How It Works", href: "#how-it-works" }
      ]
    },
    {
      title: "Resources",
      links: [
        { text: "Documentation", href: "https://github.com/LLRHook/checksinmyhead/tree/main/docs" },
        { text: "Bug Reports", href: "https://github.com/LLRHook/checksinmyhead/issues" }
      ]
    },
    {
      title: "Legal",
      links: [
        { text: "License", href: "https://github.com/LLRHook/checksinmyhead/blob/main/LICENSE" }
      ]
    }
  ];

  return (
    <footer className="pt-24 pb-12 border-t border-[#EAEAEA] dark:border-[#222]">
      <div className="container-custom">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-10 lg:gap-8 mb-16">
          <div className="lg:col-span-2">
            <Link href="/" className="flex items-center mb-6">
              <i className="fas fa-receipt text-[var(--primary)] mr-2 text-xl"></i>
              <span className="text-xl font-semibold text-[var(--accent)] dark:text-white">Checkmate</span>
            </Link>
            
            <p className="text-[var(--text-secondary)] mb-6 max-w-md">
              Checkmate is an open source, privacy-first bill-splitting app. All your data stays on your device, with no accounts required.
            </p>
            
            <div className="flex space-x-5 mb-10">
              <Link 
                href="https://github.com/LLRHook/checksinmyhead" 
                target="_blank"
                rel="noopener noreferrer"
                className="w-10 h-10 rounded-full bg-[var(--secondary)] flex items-center justify-center text-[var(--accent)] hover:bg-[var(--primary)] hover:text-white transition-colors"
                aria-label="GitHub"
              >
                <i className="fab fa-github"></i>
              </Link>
              
              <Link 
                href="mailto:checkmateapp@duck.com" 
                className="w-10 h-10 rounded-full bg-[var(--secondary)] flex items-center justify-center text-[var(--accent)] hover:bg-[var(--primary)] hover:text-white transition-colors"
                aria-label="E-Mail"
              >
                <i className="fas fa-envelope"></i>
              </Link>
            </div>
          </div>
          
          {columns.map((column, index) => (
            <FooterColumn key={index} title={column.title} links={column.links} />
          ))}
        </div>
        
        <div className="pt-8 border-t border-[#EAEAEA] dark:border-[#222] flex flex-col md:flex-row justify-between items-center">
          <p className="text-[var(--text-secondary)] text-sm mb-4 md:mb-0">
            &copy; {year} Kruski Ko. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}