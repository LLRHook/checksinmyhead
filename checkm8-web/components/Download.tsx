'use client';

import { useEffect, useState, useRef } from 'react';
import Link from 'next/link';
import Image from 'next/image';

interface DownloadButtonProps {
  icon: string;
  smallText: string;
  bigText: string;
  href: string;
  delay: number;
}

function DownloadButton({ icon, smallText, bigText, href, delay }: DownloadButtonProps) {
  const [isVisible, setIsVisible] = useState(false);
  const buttonRef = useRef<HTMLAnchorElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 }
    );

    if (buttonRef.current) {
      observer.observe(buttonRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <Link 
      href={href}
      ref={buttonRef}
      className={`flex items-center bg-white dark:bg-[var(--accent)] hover:bg-[var(--secondary)] dark:hover:bg-black text-[var(--accent)] dark:text-white px-6 py-4 rounded-xl transition-all duration-700 shadow-lg hover:shadow-xl ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
      }`}
      style={{ transitionDelay: `${delay * 100}ms` }}
      target="_blank"
      rel="noopener noreferrer"
    >
      <i className={`${icon} text-3xl text-[var(--primary)] mr-4`}></i>
      <div className="flex flex-col">
        <span className="text-xs text-[var(--text-secondary)]">{smallText}</span>
        <span className="text-lg font-semibold">{bigText}</span>
      </div>
    </Link>
  );
}

export default function Download() {
  const [isVisible, setIsVisible] = useState(false);
  const sectionRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 }
    );

    if (sectionRef.current) {
      observer.observe(sectionRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <section 
      id="download" 
      ref={sectionRef}
      className="py-24 md:py-32 gradient-bg text-white relative overflow-hidden"
    >
      {/* Background decorations */}
      <div className="absolute top-0 left-0 w-full h-full dot-pattern"></div>
      <div className="absolute -top-40 -right-40 w-96 h-96 bg-white/5 rounded-full blur-3xl"></div>
      <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-white/5 rounded-full blur-3xl"></div>
      
      <div className="container-custom relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <p className="text-white/80 font-medium mb-3">GET STARTED</p>
            <h2 
              className={`text-3xl md:text-4xl lg:text-5xl font-bold mb-6 transition-all duration-700 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
              }`}
            >
              Download Checkmate<br />today
            </h2>
            
            <p 
              className={`text-white/80 max-w-xl text-lg mb-10 transition-all duration-700 delay-100 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
              }`}
            >
              Join thousands of users who value both convenience and privacy. Checkmate is completely free and doesn&apos;t require any personal information.
            </p>
            
            <div 
              className={`space-y-4 md:space-y-0 md:flex md:space-x-4 transition-all duration-700 delay-200 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
              }`}
            >
              <DownloadButton
                icon="fab fa-apple"
                smallText="Download on the"
                bigText="App Store"
                href="#"
                delay={3}
              />
              <DownloadButton
                icon="fab fa-github"
                smallText="View project on"
                bigText="GitHub"
                href="https://github.com/LLRHook/checksinmyhead"
                delay={4}
              />
            </div>
            
            <div 
              className={`mt-12 text-white/60 text-sm flex items-center transition-all duration-700 delay-300 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
              }`}
            >
              <i className="fas fa-lock mr-2"></i>
              <span>Your privacy is guaranteed - no data leaves your device</span>
            </div>
          </div>
          
          <div 
            className={`hidden lg:flex justify-center items-center transition-all duration-1000 ${
              isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
            }`}
          >
            <div className="relative">
              {/* App screens mockup */}
              <div className="phone-mockup transform rotate-6 relative z-20">
                <div className="phone-screen">
                  <Image
                    src="/screenshot.png"
                    alt="Checkmate App"
                    width={300}
                    height={600}
                    className="object-cover h-full w-full"
                    priority
                  />
                </div>
                
                {/* Decorative elements */}
                <div className="absolute -top-6 -right-6 w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-lg">
                  <i className="fas fa-receipt text-[var(--primary)] text-xl"></i>
                </div>
                
                <div className="absolute -bottom-6 -left-6 w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-lg">
                  <i className="fas fa-shield-alt text-[var(--primary)] text-xl"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}