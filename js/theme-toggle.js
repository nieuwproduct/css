document.addEventListener('DOMContentLoaded', () => {
    const themeToggleBtn = document.getElementById('theme-toggle');
    if (!themeToggleBtn) {
        return;
    }
    const currentTheme = localStorage.getItem('theme') || 'light';

    // Apply the saved theme on load
    if (currentTheme === 'dark') {
        enableDarkMode();
    } else {
        enableLightMode();
    }

    // Toggle theme on button click
    themeToggleBtn.addEventListener('click', () => {
        if (document.body.classList.contains('dark-mode')) {
            enableLightMode();
        } else {
            enableDarkMode();
        }
    });

    function styleNavbarForTheme(isDark) {
        const navbar = document.querySelector('.navbar');
        if (!navbar) {
            return;
        }

        if (isDark) {
            navbar.classList.add('dark-mode', 'navbar-dark', 'bg-dark');
            navbar.classList.remove('navbar-light', 'bg-white');
        } else {
            navbar.classList.remove('dark-mode', 'navbar-dark', 'bg-dark');
            navbar.classList.add('navbar-light', 'bg-white');
        }
    }

    function toggleElementCollection(selector, className, enable) {
        document.querySelectorAll(selector).forEach((element) => {
            element.classList.toggle(className, enable);
        });
    }

    function enableDarkMode() {
        document.body.classList.add('dark-mode', 'bg-dark', 'text-light');
        document.body.classList.remove('bg-light', 'text-dark');
        styleNavbarForTheme(true);
        toggleElementCollection('.card', 'dark-mode', true);
        toggleElementCollection('.table', 'dark-mode', true);
        toggleElementCollection('.btn-outline-secondary', 'dark-mode', true);
        const mainElement = document.querySelector('main');
        if (mainElement) {
            mainElement.classList.add('dark-mode');
        }
        toggleElementCollection('.modal-content', 'dark-mode', true);
        toggleElementCollection('.accordion', 'dark-mode', true);
        themeToggleBtn.innerHTML = '<i class="bi bi-sun-fill"></i>';
        localStorage.setItem('theme', 'dark');
        document.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: 'dark' } }));
    }

    function enableLightMode() {
        document.body.classList.remove('dark-mode', 'bg-dark', 'text-light');
        document.body.classList.add('bg-light', 'text-dark');
        styleNavbarForTheme(false);
        toggleElementCollection('.card', 'dark-mode', false);
        toggleElementCollection('.table', 'dark-mode', false);
        toggleElementCollection('.btn-outline-secondary', 'dark-mode', false);
        const mainElement = document.querySelector('main');
        if (mainElement) {
            mainElement.classList.remove('dark-mode');
        }
        toggleElementCollection('.modal-content', 'dark-mode', false);
        toggleElementCollection('.accordion', 'dark-mode', false);
        themeToggleBtn.innerHTML = '<i class="bi bi-moon-fill"></i>';
        localStorage.setItem('theme', 'light');
        document.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: 'light' } }));
    }
});
