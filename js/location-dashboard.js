(function () {
    function getCsrfToken() {
        const name = 'csrftoken=';
        const decodedCookie = decodeURIComponent(document.cookie);
        const parts = decodedCookie.split(';');
        for (let i = 0; i < parts.length; i += 1) {
            let cookie = parts[i].trim();
            if (cookie.indexOf(name) === 0) {
                return cookie.substring(name.length, cookie.length);
            }
        }
        return '';
    }

    function reloadOnSuccess(data, modal) {
        if (data && data.success) {
            if (modal) {
                modal.hide();
            }
            window.location.reload();
        }
    }

    function handleFormResponse(response) {
        if (!response.ok) {
            return response.json().then((data) => {
                throw { response, data };
            });
        }
        return response.json();
    }

    function wireOrganizationSelect(formElement) {
        const organizationSelect = formElement.querySelector('#id_organization');
        const vlanSelect = formElement.querySelector('#id_vlan');
        if (!organizationSelect || !vlanSelect) {
            return;
        }

        function populateVlans(vlans, currentValue) {
            const previousValue = vlanSelect.value;
            const docFragment = document.createDocumentFragment();
            const placeholder = document.createElement('option');
            placeholder.value = '';
            placeholder.textContent = 'Select a VLAN';
            docFragment.appendChild(placeholder);

            vlans.forEach((vlan) => {
                const option = document.createElement('option');
                option.value = vlan.id;
                option.textContent = `${vlan.name}`;
                docFragment.appendChild(option);
            });

            vlanSelect.innerHTML = '';
            vlanSelect.appendChild(docFragment);

            const desiredValue = currentValue || previousValue || vlanSelect.dataset.current;
            if (desiredValue) {
                vlanSelect.value = desiredValue;
                if (!vlanSelect.value) {
                    // ensure current value remains available for editing even if not in the available set
                    const fallback = document.createElement('option');
                    fallback.value = desiredValue;
                    const fallbackLabel = vlanSelect.dataset.currentLabel || `Current VLAN (${desiredValue})`;
                    fallback.textContent = fallbackLabel;
                    fallback.selected = true;
                    vlanSelect.appendChild(fallback);
                }
            }
        }

        organizationSelect.addEventListener('change', () => {
            const organizationId = organizationSelect.value;
            if (!organizationId) {
                populateVlans([], null);
                return;
            }

            fetch(`/get_vlans/?organization=${organizationId}`, {
                credentials: 'same-origin',
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'Accept': 'application/json',
                },
            })
                .then(handleFormResponse)
                .then((data) => {
                    populateVlans(data.vlans || [], null);
                    vlanSelect.dataset.current = '';
                    vlanSelect.dataset.currentLabel = '';
                })
                .catch((error) => {
                    console.error('Failed to load VLANs', error);
                });
        });

        // populate existing values when editing
        const currentValue = vlanSelect.dataset.current;
        if (currentValue) {
            populateVlans([], currentValue);
        }

        const initialOrganization = organizationSelect.value;
        if (initialOrganization) {
            fetch(`/get_vlans/?organization=${initialOrganization}`, {
                credentials: 'same-origin',
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'Accept': 'application/json',
                },
            })
                .then(handleFormResponse)
                .then((data) => {
                    populateVlans(data.vlans || [], vlanSelect.dataset.current);
                })
                .catch((error) => {
                    console.error('Failed to preload VLANs', error);
                });
        }
    }

    function attachLocationFormHandlers(container, modal) {
        const formElement = container.querySelector('#location-form');
        if (!formElement) {
            return;
        }

        wireOrganizationSelect(formElement);

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
                .then(handleFormResponse)
                .then((data) => {
                    reloadOnSuccess(data, modal);
                })
                .catch((error) => {
                    if (error.data && error.data.form_html) {
                        container.innerHTML = error.data.form_html;
                        attachLocationFormHandlers(container, modal);
                        const title = error.data.title;
                        const titleElement = modal?._element?.querySelector('.modal-title');
                        if (titleElement && title) {
                            titleElement.textContent = title;
                        }
                    } else {
                        console.error('Failed to submit location form', error);
                    }
                });
        });
    }

    function attachLocationSiteFormHandlers(container, modal) {
        const formElement = container.querySelector('#location-site-form');
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
                .then(handleFormResponse)
                .then((data) => {
                    reloadOnSuccess(data, modal);
                })
                .catch((error) => {
                    if (error.data && error.data.form_html) {
                        container.innerHTML = error.data.form_html;
                        attachLocationSiteFormHandlers(container, modal);
                        const title = error.data.title;
                        const titleElement = modal?._element?.querySelector('.modal-title');
                        if (titleElement && title) {
                            titleElement.textContent = title;
                        }
                    } else {
                        console.error('Failed to submit location site form', error);
                    }
                });
        });
    }

    function fetchFormIntoModal(url, container, modal, afterRender) {
        if (!container || !modal) {
            return;
        }

        container.innerHTML = '<div class="text-center py-5"><div class="spinner-border" role="status" aria-hidden="true"></div></div>';

        fetch(url, {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'Accept': 'application/json',
            },
        })
            .then(handleFormResponse)
            .then((data) => {
                container.innerHTML = data.form_html;
                if (afterRender) {
                    afterRender(container, modal);
                }
                const title = data.title;
                const titleElement = modal?._element?.querySelector('.modal-title');
                if (titleElement && title) {
                    titleElement.textContent = title;
                }
                modal.show();
            })
            .catch((error) => {
                container.innerHTML = '<div class="alert alert-danger" role="alert">Unable to load form. Please try again.</div>';
                console.error('Failed to load form', error);
            });
    }

    function setupSearch() {
        const searchInput = document.getElementById('dashboard-search');
        if (!searchInput) {
            return;
        }
        const clearButton = document.getElementById('dashboard-search-clear');
        const accordionItems = Array.from(document.querySelectorAll('#organization-accordion .accordion-item'));

        function filterResults() {
            const query = searchInput.value.trim().toLowerCase();
            accordionItems.forEach((item) => {
                const rows = Array.from(item.querySelectorAll('.location-row'));
                let matchFound = false;
                rows.forEach((row) => {
                    const text = (row.dataset.searchText || '').toLowerCase();
                    const matches = !query || text.includes(query);
                    row.classList.toggle('d-none', !matches);
                    if (matches) {
                        matchFound = true;
                    }
                });
                item.classList.toggle('d-none', !matchFound && query);
            });
        }

        searchInput.addEventListener('input', filterResults);
        if (clearButton) {
            clearButton.addEventListener('click', () => {
                searchInput.value = '';
                filterResults();
            });
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        const locationModalElement = document.getElementById('locationFormModal');
        const locationModal = locationModalElement ? new bootstrap.Modal(locationModalElement) : null;
        const locationFormContainer = document.getElementById('location-form-container');

        const locationSiteModalElement = document.getElementById('locationSiteFormModal');
        const locationSiteModal = locationSiteModalElement ? new bootstrap.Modal(locationSiteModalElement) : null;
        const locationSiteFormContainer = document.getElementById('location-site-form-container');

        const locationDetailModalElement = document.getElementById('locationModal');
        const locationDetailModal = locationDetailModalElement ? new bootstrap.Modal(locationDetailModalElement) : null;
        const locationDetailBody = document.getElementById('modal-body-content');
        const locationDetailTitle = document.getElementById('locationModalLabel');

        setupSearch();

        document.addEventListener('click', (event) => {
            const trigger = event.target.closest('[data-action]');
            if (!trigger) {
                return;
            }

            const action = trigger.dataset.action;
            if (action === 'open-location-modal' || action === 'edit-location') {
                const url = trigger.dataset.url;
                if (url && locationModal && locationFormContainer) {
                    fetchFormIntoModal(url, locationFormContainer, locationModal, attachLocationFormHandlers);
                }
            }

            if (action === 'open-site-modal' || action === 'edit-site') {
                const url = trigger.dataset.url;
                if (url && locationSiteModal && locationSiteFormContainer) {
                    fetchFormIntoModal(url, locationSiteFormContainer, locationSiteModal, attachLocationSiteFormHandlers);
                }
            }

            if (action === 'view-location') {
                const detailUrl = trigger.dataset.detailUrl;
                const locationName = trigger.dataset.locationName;
                if (detailUrl && locationDetailModal && locationDetailBody) {
                    locationDetailBody.innerHTML = '<div class="text-center py-5"><div class="spinner-border" role="status" aria-hidden="true"></div></div>';
                    fetch(detailUrl, {
                        credentials: 'same-origin',
                        headers: {
                            'X-Requested-With': 'XMLHttpRequest',
                            'Accept': 'application/json',
                        },
                    })
                        .then(handleFormResponse)
                        .then((data) => {
                            locationDetailBody.innerHTML = data.html || '';
                            if (locationDetailTitle && locationName) {
                                locationDetailTitle.textContent = locationName;
                            }
                            locationDetailModal.show();
                        })
                        .catch((error) => {
                            console.error('Failed to load location details', error);
                            locationDetailBody.innerHTML = '<div class="alert alert-danger" role="alert">Unable to load location details.</div>';
                        });
                }
            }
        });
    });
})();
