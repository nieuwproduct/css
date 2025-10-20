(function () {
    function getCsrfToken() {
        const name = 'csrftoken=';
        const decodedCookie = decodeURIComponent(document.cookie);
        const parts = decodedCookie.split(';');
        for (let i = 0; i < parts.length; i += 1) {
            const cookie = parts[i].trim();
            if (cookie.indexOf(name) === 0) {
                return cookie.substring(name.length, cookie.length);
            }
        }
        return '';
    }

    function handleResponse(response) {
        if (!response.ok) {
            return response.json().then((data) => {
                throw { response, data };
            });
        }
        return response.json();
    }

    function reloadOnSuccess(data, modal) {
        if (data && data.success) {
            if (modal) {
                modal.hide();
            }
            window.location.reload();
        }
    }

    function attachFormHandlers(container, modal) {
        const formElement = container.querySelector('#device-form');
        if (!formElement) {
            return;
        }

        formElement.addEventListener('submit', (event) => {
            event.preventDefault();
            const formData = new FormData(formElement);
            fetch(formElement.action, {
                method: 'POST',
                body: formData,
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-CSRFToken': getCsrfToken(),
                    'Accept': 'application/json',
                },
                credentials: 'same-origin',
            })
                .then(handleResponse)
                .then((data) => {
                    reloadOnSuccess(data, modal);
                })
                .catch((error) => {
                    if (error.data && error.data.form_html) {
                        container.innerHTML = error.data.form_html;
                        attachFormHandlers(container, modal);
                        const title = error.data.title;
                        const titleElement = modal?._element?.querySelector('.modal-title');
                        if (titleElement && title) {
                            titleElement.textContent = title;
                        }
                    } else {
                        console.error('Failed to submit device form', error);
                    }
                });
        });
    }

    function fetchForm(url, container, modal, deviceName) {
        if (!container || !modal) {
            return;
        }

        container.innerHTML = '<div class="text-center py-4"><div class="spinner-border" role="status" aria-hidden="true"></div></div>';

        fetch(url, {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'Accept': 'application/json',
            },
        })
            .then(handleResponse)
            .then((data) => {
                container.innerHTML = data.form_html;
                attachFormHandlers(container, modal);
                const titleElement = modal?._element?.querySelector('.modal-title');
                const title = deviceName ? `Edit ${deviceName}` : data.title;
                if (titleElement && title) {
                    titleElement.textContent = title;
                }
                modal.show();
            })
            .catch((error) => {
                container.innerHTML = '<div class="alert alert-danger" role="alert">Unable to load device form. Please try again.</div>';
                console.error('Failed to load device form', error);
            });
    }

    document.addEventListener('DOMContentLoaded', () => {
        const modalElement = document.getElementById('deviceFormModal');
        if (!modalElement) {
            return;
        }
        const modal = new bootstrap.Modal(modalElement);
        const container = document.getElementById('device-form-container');

        document.addEventListener('click', (event) => {
            const trigger = event.target.closest('[data-action="edit-device"]');
            if (!trigger) {
                return;
            }
            event.preventDefault();
            const url = trigger.dataset.url;
            const deviceName = trigger.dataset.deviceName;
            if (url) {
                fetchForm(url, container, modal, deviceName);
            }
        });

        const modalContent = container.closest('.modal-content');
        if (modalContent && document.body.classList.contains('dark-mode')) {
            modalContent.classList.add('dark-mode');
        }

        document.addEventListener('theme:changed', (event) => {
            if (!modalContent) {
                return;
            }
            if (event.detail?.theme === 'dark') {
                modalContent.classList.add('dark-mode');
            } else {
                modalContent.classList.remove('dark-mode');
            }
        });
    });
})();
