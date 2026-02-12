import { useState, useRef, useEffect, useCallback } from "react";

export function useCollapsible(defaultOpen = false) {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  const contentRef = useRef<HTMLDivElement>(null);
  const [height, setHeight] = useState(defaultOpen ? "auto" : "0px");

  useEffect(() => {
    if (contentRef.current) {
      setHeight(isOpen ? `${contentRef.current.scrollHeight}px` : "0px");
    }
  }, [isOpen]);

  const toggle = useCallback(() => setIsOpen((prev) => !prev), []);

  return { isOpen, toggle, contentRef, height };
}
