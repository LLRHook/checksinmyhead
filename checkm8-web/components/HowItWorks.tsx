'use client';

import { useEffect, useState, useRef } from 'react';
import Image from 'next/image';

interface StepProps {
  number: number;
  title: string;
  description: string;
  icon: string;
  delay: number;
  imageSrc: string;
}

function Step({ number, title, description, icon, delay }: StepProps) {
  const [isVisible, setIsVisible] = useState(false);
  const stepRef = useRef<HTMLDivElement>(null);

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

    if (stepRef.current) {
      observer.observe(stepRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <div 
      ref={stepRef}
      className={`flex flex-col md:flex-row items-start md:items-center gap-6 transition-all duration-700 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
      }`}
      style={{ transitionDelay: `${delay * 100}ms` }}
    >
      {/* Step number */}
      <div className="flex-shrink-0 w-14 h-14 rounded-full bg-[var(--primary)] text-white text-xl font-bold flex items-center justify-center">
        {number}
      </div>
      
      {/* Step content */}
      <div className="flex-grow">
        <div className="flex items-center mb-2">
          <div className="w-8 h-8 bg-[var(--secondary)] rounded-full flex items-center justify-center mr-3">
            <i className={`${icon} text-[var(--primary)]`}></i>
          </div>
          <h3 className="text-xl font-semibold text-[var(--accent)] dark:text-white">{title}</h3>
        </div>
        <p className="text-[var(--text-secondary)]">{description}</p>
      </div>
    </div>
  );
}

export default function HowItWorks() {
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

  const steps: StepProps[] = [
    {
      number: 1,
      title: "Select Participants",
      description: "Choose who's splitting the bill - no need to create accounts or access your contacts.",
      icon: "fas fa-users",
      delay: 1,
      imageSrc: "/add.png"
    },
    {
      number: 2,
      title: "Enter Bill Details",
      description: "Add items, subtotal, tax, and tip. Customize to match your receipt exactly.",
      icon: "fas fa-receipt",
      delay: 2,
      imageSrc: "/bill.png"
    },
    {
      number: 3,
      title: "Assign Items",
      description: "Easily assign items to people with flexible splitting options for shared items.",
      icon: "fas fa-tasks",
      delay: 3,
      imageSrc: "/assign.png"
    },
    {
      number: 4,
      title: "Share Results",
      description: "Get a clean breakdown of who owes what and share it directly with your friends.",
      icon: "fas fa-share-alt",
      delay: 4,
      imageSrc: "/summary.png"
    }
  ];

  // Track which step is being hovered
  const [currentStep, setCurrentStep] = useState(1);

  // Simple hover handler
  const handleStepHover = (stepNumber: number) => {
    setCurrentStep(stepNumber);
  };

  return (
    <section
      id="how-it-works"
      ref={sectionRef}
      className="py-24 md:py-32"
    >
      <div className="container-custom">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <p className="text-[var(--primary)] font-medium mb-3">THE PROCESS</p>
            <h2
              className={`text-3xl md:text-4xl lg:text-5xl font-bold mb-6 text-[var(--accent)] dark:text-white transition-all duration-700 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
              }`}
            >
              Split bills in four<br />simple steps
            </h2>

            <p
              className={`text-[var(--text-secondary)] mb-12 text-lg transition-all duration-700 delay-100 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
              }`}
            >
              Checkmate makes it easy to divide expenses fairly, with a simple four-step process that respects your privacy at every stage.
            </p>

            <div className="space-y-10">
              {steps.map((step) => (
                <div
                  key={step.number}
                  onMouseEnter={() => handleStepHover(step.number)}
                  className="cursor-pointer transition-all duration-300 hover:translate-x-1"
                >
                  <Step
                    number={step.number}
                    title={step.title}
                    description={step.description}
                    icon={step.icon}
                    delay={step.delay} imageSrc={''}                  />
                </div>
              ))}
            </div>
          </div>

          <div
            className={`hidden lg:block relative transition-all duration-1000 ${
              isVisible ? 'opacity-100 scale-100' : 'opacity-0 scale-95'
            }`}
          >
            <div className="relative ml-16">
              {/* Background element */}
              <div className="absolute -top-16 -left-16 w-72 h-72 bg-[var(--primary)]/5 rounded-full blur-3xl"></div>

              {/* Phone mockups */}
              <div className="relative transform rotate-6 z-10 ml-18">
                <div className="phone-mockup">
                  <div className="phone-screen">
                    <Image
                      src={steps[currentStep - 1].imageSrc}
                      alt={`Checkmate App - ${steps[currentStep - 1].title}`}
                      width={290}
                      height={615}
                      className="object-contain h-full w-full gif-smooth"
                      priority
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}