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

$('.merge.step3').ready(function () {
    $('.selectpicker').selectpicker({
    });

    const data = $('#data').data();
    const $organization = $('#organization');
    const $repository = $('#repository');
    const $source_branch = $('#source_branch');
    const $target_branch = $('#target_branch');

    
    $target_branch.selectpicker({
        title: 'Target Branch',
        selectedTextFormat: 'count > 0',
        countSelectedText: function (numSelected, numTotal) {
              return (numSelected == 1) ? "{0} Feature activated" : "{0} Features activated";
        }
    });
 
    const $sourceSelect = $source_branch.selectpicker({
        title: 'Source Branch',
        selectedTextFormat: 'count > 0',
        countSelectedText: function (numSelected, numTotal) {
              return (numSelected == 1) ? "{0} Feature activated" : "{0} Features activated";
        },
        noneResultsText: '<div class="text-center">\
              <button value={0} onclick="createNewBranchOption($(this))" type="button" class="btn-sm btn-primary btn"> \
                This is a new branch \
              </button></div>',
        liveSearchPlaceholder: 'New Branch / Search',
    }); 


    window.createNewBranchOption = function(button) {
        const option = new Option(button.val(), button.val(), false, true);
        
        createdOptionHtml = '<div class= "row"> \
                            <div class="col">'+ button.val() + '</div>\
                            <div class="col text-right mr-2">\
                                <span class="badge badge-success">Branch will be created</span>\
                            </div> \
                          </div>'
        
        option.setAttribute('data-content', createdOptionHtml);
        $sourceSelect.append(option);
        $sourceSelect.selectpicker('refresh');
    }
    
    
    $('#continue').on('click', checkInputAndContinue)
    $organization.on('changed.bs.select', function() {
        window.location.href = `/create/${$organization.val()}`;
    });
    
    $repository.on('changed.bs.select', function() {
        window.location.href = `/create/${$organization.val()}/${$repository.val()}`;
    });
    
    function checkInputAndContinue() {
        var sourceBranch = encodeURIComponent($source_branch.val());
        var targetBranch = encodeURIComponent($target_branch.val());

        if (sourceBranch.length === 0)
            showError('Source Branch is empty!');
        else if (sourceBranch === targetBranch)
            showError('Source and Target Branch are the same!');
        else
            window.location.href = `/create/${$organization.val()}/${$repository.val()}/${sourceBranch}/${targetBranch}`;
    }

    function showError(text) {
        $('#errorText').html(text);
        $('#errorMessage').fadeTo('fast', 1);
        $('#errorMessage').show();
    }
});