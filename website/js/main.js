// OllamaBot Website JavaScript

// Copy install command to clipboard
function copyInstallCommand() {
    const command = 'curl -fsSL https://ollamabot.com/install.sh | sh';
    navigator.clipboard.writeText(command).then(() => {
        const btn = document.querySelector('.copy-btn');
        const originalHTML = btn.innerHTML;
        btn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>';
        btn.style.background = '#7dcfff';
        btn.style.color = '#1a1b26';
        
        setTimeout(() => {
            btn.innerHTML = originalHTML;
            btn.style.background = '';
            btn.style.color = '';
        }, 2000);
    });
}

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Nav background on scroll
const nav = document.querySelector('.nav');
let lastScroll = 0;

window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;
    
    if (currentScroll > 50) {
        nav.style.background = 'rgba(26, 27, 38, 0.98)';
    } else {
        nav.style.background = 'rgba(26, 27, 38, 0.9)';
    }
    
    lastScroll = currentScroll;
});

// Intersection Observer for animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            observer.unobserve(entry.target);
        }
    });
}, observerOptions);

// Observe cards for animation
document.querySelectorAll('.feature-card, .mode-card, .model-card').forEach(card => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';
    card.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
    observer.observe(card);
});

// Add visible class styles
const style = document.createElement('style');
style.textContent = `
    .feature-card.visible,
    .mode-card.visible,
    .model-card.visible {
        opacity: 1 !important;
        transform: translateY(0) !important;
    }
`;
document.head.appendChild(style);

// Hero logo animation enhancement
const heroLogo = document.querySelector('.hero-logo');
if (heroLogo) {
    let mouseX = 0;
    let mouseY = 0;
    let logoX = 0;
    let logoY = 0;
    
    document.addEventListener('mousemove', (e) => {
        const rect = heroLogo.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;
        
        mouseX = (e.clientX - centerX) / 50;
        mouseY = (e.clientY - centerY) / 50;
    });
    
    function animateLogo() {
        logoX += (mouseX - logoX) * 0.1;
        logoY += (mouseY - logoY) * 0.1;
        
        heroLogo.style.transform = `translate(${logoX}px, ${logoY}px)`;
        requestAnimationFrame(animateLogo);
    }
    
    animateLogo();
}

// Console branding
console.log('%c∞ OllamaBot', 'color: #7dcfff; font-size: 24px; font-weight: bold;');
console.log('%cLocal AI, Infinite Possibilities', 'color: #9aa5ce; font-size: 14px;');
console.log('%chttps://github.com/ollamabot/ollamabot', 'color: #7aa2f7; font-size: 12px;');
