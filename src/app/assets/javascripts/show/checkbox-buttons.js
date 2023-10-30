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
    updateCheckboxes();
});


function updateCheckbox($widget) {
    // Settings
    var $button = $widget,
        $checkbox = $widget.find('input:hidden'),
        color = $button.data('color'),
        settings = {
            on: {
                icon: 'octicon octicon-check'
            },
            off: {
                icon: 'octicon octicon-x'
            }
        };

    // Event Handlers
    $button.one('click', function () {
        $checkbox.val(!($checkbox.val() == 'true'));
        $checkbox.triggerHandler('change');
    });
    $checkbox.one('change', function () {
        updateCheckbox($(this).parent());
    });

    var isChecked = $checkbox.val() == 'true';
    var isTextCheckbox = $button.hasClass('btn-text');

    // Set the button's state
    $button.data('state', (isChecked) ? "on" : "off");

    var icon = $button.data('icon');

    $button.find('.icon-stack').remove();
    $iconStackSpan = $('<span class="icon-stack"></span>');

    
    // Update the button's state
    if(isTextCheckbox) {
        isChecked ? $button.css('text-decoration', 'none') : $button.css('text-decoration', 'line-through');
    } else { // checkbox with icon
        if(icon) { // icon is defined
            if(isChecked)
                $iconStackSpan.append('<i class="octicon octicon-'+icon+'"></i>');
            else {
                $iconStackSpan.append('<i class="octicon octicon-'+icon+'"></i>');
                $iconStackSpan.append('<i style="position:absolute;left:2px;top:2px;font-size:32px" class="octicon octicon-circle-slash text-secondary"></i>');
            }
        } else { // icon is not defined
            isChecked? $iconStackSpan.append('<i class="octicon octicon-check"></i>') : $iconStackSpan.append('<i class="octicon octicon-x"></i>');
        }
    }

    if(color) {
        isChecked? $button.addClass( "btn-" + color ) : $button.removeClass( "btn-" + color );
    }

    $button.prepend($iconStackSpan);
}


function updateCheckboxes() {
    $('.button-checkbox').each(function () {
        updateCheckbox($(this));
    });
}