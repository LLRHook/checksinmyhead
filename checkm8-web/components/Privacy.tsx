'use client';

import { useEffect, useState, useRef } from 'react';

export default function Privacy() {
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

  const guarantees = [
    { text: "No Data Collection", icon: "fa-ban" },
    { text: "Zero Cloud Storage", icon: "fa-cloud" },
    { text: "No Account Required", icon: "fa-user-slash" },
    { text: "No Tracking", icon: "fa-location-dot" }
  ];

  return (
    <section 
      id="privacy" 
      ref={sectionRef}
      className="py-24 md:py-32 overflow-hidden bg-[var(--primary)] text-white relative"
    >
      {/* Background elements */}
      <div className="absolute top-0 left-0 w-full h-full dot-pattern"></div>
      <div className="absolute top-0 right-0 w-1/3 h-full bg-gradient-to-l from-[var(--primary-light)]/30 to-transparent"></div>
      <div className="absolute bottom-0 left-0 w-1/3 h-full bg-gradient-to-t from-[var(--primary-dark)]/30 to-transparent"></div>
      
      <div className="container-custom relative z-10">
        <div className="text-center mb-16">
          <p className="text-white/80 font-medium mb-3">OUR COMMITMENT</p>
          <h2 
            className={`text-3xl md:text-4xl lg:text-5xl font-bold mb-6 transition-all duration-700 ${
              isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
            }`}
          >
            Privacy: A Core Value,<br />Not a Feature
          </h2>
          <p 
            className={`text-white/80 max-w-2xl mx-auto text-lg transition-all duration-700 delay-100 ${
              isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
            }`}
          >
            In today&apos;s digital landscape, users have grown accustomed to trading their personal data for convenience. Checkmate was built on a fundamental belief: you shouldn&apos;t need to create an account to split a bill with friends.
          </p>
        </div>
        
        <div 
          className={`grid grid-cols-1 md:grid-cols-2 gap-14 items-center transition-all duration-700 delay-200 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
          }`}
        >
          <div className="relative overflow-hidden rounded-3xl aspect-square md:aspect-auto md:h-[500px]">
            <div className="absolute inset-0 bg-[var(--primary-dark)] rounded-3xl overflow-hidden">
              <div className="w-full h-full flex items-center justify-center">
                <div className="w-64 h-64 md:w-80 md:h-80 relative">
                  <div className="absolute inset-0 flex items-center justify-center">
                    <i className="fas fa-shield-alt text-8xl md:text-9xl text-white/20"></i>
                  </div>
                  
                  <div className="absolute w-full h-full animate-spin-slow" style={{ animationDuration: '30s' }}>
                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-4 h-4 bg-white/40 rounded-full"></div>
                    <div className="absolute top-1/4 right-0 w-3 h-3 bg-white/30 rounded-full"></div>
                    <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-5 h-5 bg-white/40 rounded-full"></div>
                    <div className="absolute top-1/4 left-0 w-2 h-2 bg-white/30 rounded-full"></div>
                  </div>
                </div>
              </div>
              
              <div className="absolute top-0 left-0 w-full h-full bg-gradient-to-br from-[var(--primary-light)]/40 to-transparent"></div>
            </div>
          </div>
          
          <div>
            <h3 className="text-2xl font-bold mb-6">How We Protect Your Privacy</h3>
            <p className="text-white/80 mb-8">
              Unlike most apps that require you to create an account and upload your data to their servers, Checkmate works entirely on your device. Your bill information, contacts, and history never leave your phone.
            </p>
            
            <div className="space-y-5">
              {guarantees.map((guarantee, index) => (
                <div 
                  key={index} 
                  className="flex items-center" 
                  style={{ animationDelay: `${(index + 4) * 100}ms` }}
                >
                  <div className="w-12 h-12 bg-white/10 rounded-full flex items-center justify-center mr-4">
                    <i className={`fas ${guarantee.icon} text-white`}></i>
                  </div>
                  <div className="font-medium">{guarantee.text}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}