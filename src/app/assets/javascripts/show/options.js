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
    const $options = $this.find('#options').selectpicker({
        title: 'MegaMerge Features',
        selectedTextFormat: 'count > 0',
        countSelectedText: function (numSelected, numTotal) {
              return (numSelected == 1) ? "{0} Feature activated" : "{0} Features activated";
        }
    });
    
    $options.on('changed.bs.select', updateHiddenInputs);
    $options.on('loaded.bs.select', updateHiddenInputs);
    
    function updateHiddenInputs() {
        $('#options > :input').remove();
        $('#options option').each(function() {
          $('<input>').attr({
              type: 'hidden',
              name: 'meta_repo['+this.value+']',
              value: this.selected
          }).appendTo('#options');
        });
        
    }

});