'use client';

import { useEffect, useState, useRef } from 'react';

interface TestimonialProps {
  quote: string;
  name: string;
  title: string;
  initials: string;
  delay: number;
}

function TestimonialCard({ quote, name, title, initials, delay }: TestimonialProps) {
  const [isVisible, setIsVisible] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);

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

    if (cardRef.current) {
      observer.observe(cardRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <div 
      ref={cardRef}
      className={`testimonial-card hover:shadow-md transition-all duration-700 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
      }`}
      style={{ transitionDelay: `${delay * 100}ms` }}
    >
      <div className="flex items-center mb-6">
        <div className="w-10 h-10 bg-[var(--primary)] text-white rounded-full flex items-center justify-center font-medium mr-4">
          {initials}
        </div>
        <div>
          <h4 className="font-medium text-[var(--accent)] dark:text-white">{name}</h4>
          <p className="text-[var(--text-secondary)] text-sm">{title}</p>
        </div>
      </div>
      
      <div className="relative">
        <i className="fas fa-quote-left text-[var(--primary)]/10 text-4xl absolute -top-2 -left-1"></i>
        <p className="text-[var(--text-secondary)] relative z-10 pl-6">{quote}</p>
      </div>
      
      <div className="mt-6 flex">
        {[1, 2, 3, 4, 5].map((star) => (
          <i key={star} className="fas fa-star text-[var(--primary)]"></i>
        ))}
      </div>
    </div>
  );
}

export default function Testimonials() {
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

  const testimonials: TestimonialProps[] = [
    {
      quote: "Finally, a bill-splitting app that doesn't require me to upload my entire contact list just to figure out who owes what. Clean interface, works exactly as advertised, and respects my privacy.",
      name: "John D.",
      title: "Frequent Traveler",
      initials: "JD",
      delay: 0
    },
    {
      quote: "I love how Checkmate lets me split bills without forcing everyone to download the app or create accounts. After dinner, I just share the breakdown via text and we're done. No fuss, no data mining.",
      name: "Sarah M.",
      title: "Restaurant Enthusiast",
      initials: "SM",
      delay: 1
    },
    {
      quote: "As someone who organizes group trips, Checkmate has been a game-changer. The tax and tip distribution is fair, the interface is intuitive, and I don't have to worry about yet another app collecting data on my friends.",
      name: "Robert L.",
      title: "Trip Organizer",
      initials: "RL",
      delay: 2
    }
  ];

  return (
    <section 
      ref={sectionRef}
      className="py-24 md:py-32 bg-gradient-to-b from-white to-[var(--secondary)] dark:from-black dark:to-[var(--accent)]"
    >
      <div className="container-custom">
        <div className="text-center mb-16">
          <p className="text-[var(--primary)] font-medium mb-3">TESTIMONIALS</p>
          <h2 
            className={`text-3xl md:text-4xl lg:text-5xl font-bold mb-6 text-[var(--accent)] dark:text-white transition-all duration-700 ${
              isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
            }`}
          >
            What our users say
          </h2>
          <p 
            className={`text-[var(--text-secondary)] max-w-2xl mx-auto text-lg transition-all duration-700 delay-100 ${
              isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
            }`}
          >
            Join thousands of privacy-conscious users who love Checkmate&apos;s simple approach to bill splitting.
          </p>
        </div>
        
        <div 
          className={`grid grid-cols-1 md:grid-cols-3 gap-8 transition-all duration-700 delay-200 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
          }`}
        >
          {testimonials.map((testimonial, index) => (
            <TestimonialCard
              key={index}
              quote={testimonial.quote}
              name={testimonial.name}
              title={testimonial.title}
              initials={testimonial.initials}
              delay={testimonial.delay}
            />
          ))}
        </div>
        
        <div 
          className={`flex justify-center mt-16 transition-all duration-700 delay-300 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
          }`}
        >
          <a href="#download" className="btn-primary">
            Try it yourself
          </a>
        </div>
      </div>
    </section>
  );
}