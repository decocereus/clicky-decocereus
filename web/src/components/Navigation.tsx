import { useState, useEffect } from 'react';
import { Menu, X } from 'lucide-react';

export function Navigation() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 100);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
    setIsMobileMenuOpen(false);
  };

  return (
    <>
      <nav
        className={`fixed top-0 left-0 right-0 z-100 transition-all duration-300 ${
          isScrolled
            ? 'bg-warm/90 backdrop-blur-md py-3'
            : 'bg-transparent py-5'
        }`}
      >
        <div className="max-w-7xl mx-auto px-6 flex items-center justify-between">
          {/* Logo */}
          <a href="#" className="text-charcoal font-semibold text-xl tracking-tight">
            Clicky
          </a>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-10">
            <button
              onClick={() => scrollToSection('sees-screen')}
              className="text-muted-elegant hover:text-charcoal transition-colors text-sm"
            >
              How it works
            </button>
            <button
              onClick={() => scrollToSection('knows-apps')}
              className="text-muted-elegant hover:text-charcoal transition-colors text-sm"
            >
              Apps
            </button>
            <button
              onClick={() => scrollToSection('pricing')}
              className="text-muted-elegant hover:text-charcoal transition-colors text-sm"
            >
              Pricing
            </button>
            <button
              id="nav-download-cta"
              data-companion-cta-id="nav-download-cta"
              data-companion-target-kind="cta"
              className="bg-charcoal text-warm px-5 py-2.5 rounded-full text-sm font-medium hover:bg-lavender transition-colors"
            >
              Download
            </button>
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            className="md:hidden text-charcoal p-2"
          >
            {isMobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </nav>

      {/* Mobile Menu */}
      {isMobileMenuOpen && (
        <div className="fixed inset-0 z-99 bg-warm/98 backdrop-blur-lg md:hidden">
          <div className="flex flex-col items-center justify-center h-full gap-8">
            <button
              onClick={() => scrollToSection('sees-screen')}
              className="text-charcoal text-2xl font-serif-italic"
            >
              How it works
            </button>
            <button
              onClick={() => scrollToSection('knows-apps')}
              className="text-charcoal text-2xl font-serif-italic"
            >
              Apps
            </button>
            <button
              onClick={() => scrollToSection('pricing')}
              className="text-charcoal text-2xl font-serif-italic"
            >
              Pricing
            </button>
            <button
              id="nav-mobile-download-cta"
              data-companion-cta-id="nav-mobile-download-cta"
              data-companion-target-kind="cta"
              className="bg-charcoal text-warm px-6 py-3 rounded-full text-lg font-medium mt-4"
            >
              Download
            </button>
          </div>
        </div>
      )}
    </>
  );
}

export default Navigation;
