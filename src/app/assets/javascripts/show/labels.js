/* Copyright (c) 2018 Continental Automotive GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

$('.merge.show').ready(function () {

    const $this = $(this);
    const $form = $this.find('#save-form');
    const $labels = $this.find('#labels').selectpicker({
        title: 'Labels',
    
    });
    /*const $labels = $this.find('#labels').select2({
        maximumSelectionLength: null,
        placeholder: 'Set labels',
        tags: true,
        theme: 'bootstrap',
        closeOnSelect: false,
        templateSelection: function (tag, container) {
            const dataColor = tag.element.getAttribute('data-color');
            $(container).css({
                'background-color': dataColor,
                'color': '#fdfdfd'
            });
            const color = tinycolor(dataColor).isLight() ? '#000' : '#fff';
            return $('<span>').css({ color: color }).text(tag.text);
        },
        templateResult: function (tag) {
            if (tag.disabled) return null;
            if (!tag.element) {
                return tag
            }

            return $('<div>')
                .append($('<span class="badge">').css({
                    'background-color': tag.element.getAttribute('data-color'),
                    width: '15px',
                    height: '15px',
                    'vertical-align': 'middle',
                    'margin-right': '5px'
                }).text(' '))
                .append($('<span>').text(tag.text));
        }
    });*/

    const auth_token = $form.find('input[name="authenticity_token"]')[0].value;
    const repository = $form.data('repository');
    const id = parseInt($form.data('id'));

    function showLabels(labels) {
        $labels.show();
        labels.forEach(label => {
            const option = new Option(label.name, label.name, false, false)
            //option.setAttribute('data-content', '#' + label.color)
            option.setAttribute('data-content', generateSelectOptionView(label).html())
            //console.log($labels.children())
            $labels.children().first().append(option)
        });
        //$labels.trigger('change');
        $labels.selectpicker('refresh');
    }
    
    function generateSelectOptionView(label) {
        return $('<div>')
                .append($('<span class="badge">').css({
                    'background-color': '#'+label.color,
                    width: '15px',
                    height: '15px',
                    'vertical-align': 'middle',
                    'margin-right': '5px'
                }).text(' '))
                .append($('<span>').text(label.name));
    }

    function getLabels() {
        return fetch('/api/v1/' + repository + '/labels', {
            credentials: 'include'
        })
            .then(r => r.json())
            .catch(console.error)
            .then(showLabels)
    }

    function getSelectedLabels(id) {
        return fetch('/api/v1/' + repository + '/' + id + '/labels', {
            credentials: 'include'
        })
            .then(r => r.json())
            .catch(console.error)
            .then(function (selectedLabels) {
                selectedLabels.forEach(selected => {

                    $labels.children().first().children().each((i, opt) => {
                        if (opt.value === selected.name) {
                            opt.selected = true;
                        }
                    });
                });
                //$labels.trigger('change');
                $labels.selectpicker('refresh');
            });
    }

    function registerLabelEventHandler() {
        $labels.on('hidden.bs.select', function () {
            saveLabels(id, $(this).val());
        });
    }

    function saveLabels(id, labels) {
        if (labels === null) labels = []

        console.log(JSON.stringify(labels))

        return fetch('/api/v1/' + repository + '/' + id + '/labels/', {
            credentials: 'include',
            method: 'PUT',
            headers: {
                "Content-Type": 'application/json',
                'X-CSRF-Token': auth_token
            },
            body: JSON.stringify(labels)
        })
            .then(console.log)
            .catch(console.error);
    }

    if (id !== 0) {
        getLabels()
            .then(() => getSelectedLabels(id))
            .catch(console.error)
            .then(registerLabelEventHandler)
    }
});