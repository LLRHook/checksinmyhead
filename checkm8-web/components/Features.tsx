'use client';

import { useEffect, useState, useRef } from 'react';

interface FeatureProps {
  icon: string;
  title: string;
  description: string;
  delay: number;
}

function FeatureCard({ icon, title, description, delay }: FeatureProps) {
  const [isVisible, setIsVisible] = useState(false);
  const featureRef = useRef<HTMLDivElement>(null);

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

    if (featureRef.current) {
      observer.observe(featureRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <div 
      ref={featureRef}
      className={`feature-card hover:scale-105 transition-all duration-500 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
      }`}
      style={{ transitionDelay: `${delay * 100}ms` }}
    >
      <div className="feature-icon">
        <i className={icon}></i>
      </div>
      <h3 className="text-lg font-semibold mb-3 text-[var(--accent)] dark:text-white">{title}</h3>
      <p className="text-[var(--text-secondary)] dark:text-white/70">{description}</p>
    </div>
  );
}

export default function Features() {
  const features: (FeatureProps & { id: number })[] = [
    {
      id: 1,
      icon: "fas fa-shield-alt",
      title: "Zero Cloud Storage",
      description: "Your data never leaves your device. We don't store your information in the cloud, so there's nothing to leak or sell.",
      delay: 0
    },
    {
      id: 2,
      icon: "fas fa-user-slash",
      title: "No Accounts Required",
      description: "Use Checkmate without creating an account. No email, no passwords, no personal data collection.",
      delay: 1
    },
    {
      id: 3,
      icon: "fas fa-calculator",
      title: "Fair Split Calculations",
      description: "Split bills proportionally based on what each person ordered, including tax and tip distribution.",
      delay: 2
    },
    {
      id: 4,
      icon: "fas fa-share-alt",
      title: "Easy Sharing",
      description: "Share bill breakdowns via text message or any messaging app without storing contact information.",
      delay: 3
    },
    {
      id: 5,
      icon: "fas fa-history",
      title: "Bill History",
      description: "Review past bills with local storage only. Your history stays on your device and nowhere else.",
      delay: 4
    },
    {
      id: 6,
      icon: "fas fa-moon",
      title: "Dark Mode Support",
      description: "Enjoy a beautiful interface that adapts to your system preferences with light and dark themes.",
      delay: 5
    },
  ];

  return (
    <section id="features" className="py-20 md:py-28 bg-gradient-to-b from-white to-[var(--secondary)] dark:from-[#121212] dark:to-black">
      <div className="container-custom">
        <div className="text-center mb-20">
          <p className="text-[var(--primary)] font-medium mb-3">FEATURES</p>
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-6 text-[var(--accent)] dark:text-white">
            Designed with privacy in mind
          </h2>
          <p className="text-[var(--text-secondary)] max-w-2xl mx-auto text-lg">
            Every feature in Checkmate was built to protect your privacy while making bill-splitting simple.
          </p>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature) => (
            <FeatureCard
              key={feature.id}
              icon={feature.icon}
              title={feature.title}
              description={feature.description}
              delay={feature.delay}
            />
          ))}
        </div>
      </div>
    </section>
  );
}