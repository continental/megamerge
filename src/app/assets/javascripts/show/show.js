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
    class Loader {
        constructor(startingCount = 0) {
            this.count = startingCount;
        }

        isLoading() {
            return this.count > 0;
        }

        inc(increment = 1) {
            if (!this.isLoading()) {
                this.fadeInputs(true);
            }
            this.count += increment;
        }

        dec(decrement = 1) {
            this.count < decrement ? 0 : this.count -= decrement;
            if (!this.isLoading()) {
                this.fadeInputs(false);
            }
        }

        fadeInputs(fadeIn) {
            if (fadeIn) {
                $('#disableInputsDivOverlay').show();
                $('#disableInputsDivOverlay').fadeTo('fast', 1);
            } else {
                $('#disableInputsDivOverlay').fadeTo('fast', 0).promise().done(function () {
                    $('#disableInputsDivOverlay').hide();
                });

            }
        }
    }

    const loader = new Loader();

    const $tables = $('table');
    const $subRepoTable = $('#sub-repo-table');

    const $selectSubRepos = $('#select-sub-repo-add');
    const $findAllSubRepos = $('#find-all-sub-repos');
    const $subRepos = $('#sub-repos');
    
    const $templateSelection = $('#template_selection');
    const $bodyInput = $('#body_input')

    const $saveChangesBtn = $('#save-changes-btn');
    const $cancelBtn = $('#cancel-btn');
    const $performMegaMergeBtn = $('#perform-mega-merge-btn');
    const $closePRBtn = $('#close-pr-button');
    const $reopenPRBtn = $('#reopen-pr-button');
    const $r4rBtn = $('#r4r-btn');
    const $deleteBtn = $('#delete-btn');
    const $metaTitle = $('#meta-title');

    const $formInputs = $('[data-form-input]');

    const selectpickerOptions = (config = {}) => Object.assign({ }, config);
    

    initSelectpickers($('.show-selectpicker'));

    $tables.on('click', 'button[data-type="remove-btn"]', function () { removeRow(this) });
    
    // Hide tables that aren't needed
    $tables.each((_i, el) => setTableVisibility($(el)));


    $selectSubRepos.selectpicker(selectpickerOptions());
    $selectSubRepos.on('changed.bs.select', function() {addSubRepo()});

    $findAllSubRepos.on('click', function () {addSubRepos()});
    
    $templateSelection.selectpicker(selectpickerOptions());
    $templateSelection.on('changed.bs.select',selectTemplate);
    
    $subRepos.on('changed.bs.select	', '.show-selectpicker', updateSubRepoRow);

    // fork button in subrepos
    $subRepos.on('click', '.open-fork-menu',   function() {
        $(this).parent().parent().find(".fork-menu").each(function() {
            $(this).toggle();   
        });
    });

    $closePRBtn.on('click', () => {loader.inc();redirectToAction('close')});
    $reopenPRBtn.on('click', () => {loader.inc();redirectToAction('reopen')});
    $deleteBtn.on('click', () => {loader.inc();redirectToAction('delete')});
    $r4rBtn.on('click', () => {loader.inc();redirectToAction('r4r')});
    $performMegaMergeBtn.on('click', () => {loader.inc();redirectToAction('merge')});
    $cancelBtn.on('click', () => {loader.inc();location.reload()});
    $metaTitle.on('input', () => checkTitle());
    $saveChangesBtn.on('click', () => {loader.inc();enableAllSelects();});


    $formInputs.each(function () {
        const $this = $(this);
        $this.on($this.data('form-input'), () => setPageDirty());
    });

    // save button only visible if this is a new MM-PR
    if (pr_id === 0 || pr_outdated || pr_inconsistent) {
        $saveChangesBtn.show();
        $cancelBtn.show();
    } else {
        $saveChangesBtn.hide();
        $cancelBtn.hide();
    }
    
    function enableAllSelects() {
        $("select").each(function () {
            $(this).removeAttr("disabled");
        });
        return false;
    }

    // loads all DOM elements with '.show-selectpicker' .css class
    function initSelectpickers($selectpickers) {
        $selectpickers.each((_i, el) => $(el).selectpicker(selectpickerOptions()));
    }

    function checkTitle() {
        if($metaTitle.val())
            $metaTitle.removeClass('is-invalid');
        else
            $metaTitle.addClass('is-invalid');
        updateSaveAbleButton();
    }

    function setPageDirty() {
        $saveChangesBtn.show();
        $cancelBtn.show();
        $performMegaMergeBtn.hide();
        updateSaveAbleButton();
    }

    function updateSaveAbleButton() {
        var saveAble = true;

        $(document).find('input[id^="saveAble"]').each(function () {
            if ($(this).val() === "false")
                saveAble = false;
        });
        if(!$metaTitle.val())
            saveAble = false;

        $saveChangesBtn.prop('disabled', !saveAble);
    }

    function redirectToAction(action) {
        loader.inc();
        window.location.href = "/do/" + action + "/" + owner + "/" + repository + "/" + pr_id;
    }


    // makes table visible if its body contains more than 0 table rows
    function setTableVisibility($table) {
        if ($table.find('tbody').children().length === 0) {
            $table.hide();
        } else {
            $table.show();
        }
    }


    // checks if a table row with sub repo id exists in subRepoTable
    function hasExistingRow(identifier) {
        return getExistingRow(identifier).length > 0;
    }

    // jquery for finding a table row with sub repo id
    function getExistingRow(identifier) {
        return $subRepos.find(`tr[id="subrepos/${identifier}"]`);
    }
    
    function selectTemplate(){
        $bodyInput.val($templateSelection.val())
        return;
    }


    // removes table row
    function removeRow(el) {
        const $row = $(el).closest('tr');
        const $table = $row.closest('table');
        $row.remove();
        setTableVisibility($table);
        setPageDirty();
    }

    // if a sub repo is not already in the subRepos
    function addSubRepo() {
        if($selectSubRepos.val() == ""){
            return;
        }
        if (hasExistingRow($selectSubRepos.val())) {
            $selectSubRepos.selectpicker('val',null);
            return;
        }
        parts = $selectSubRepos.val().split('/')
        return appendSubRepo( parts[0], 
                              parts[1], 
                              $('input[name="meta_repo\[source_branch\]"]').val(), 
                              $('input[name="meta_repo\[target_branch\]"]').val(),
                              owner+'/'+repository,
                              pr_id,
                              parts.slice(2).join("/")
                            );
    }
  
   // get call for sub repo, appends response to subRepos
   function appendSubRepo(owner, repo, source_branch, target_branch, parent_full_name, parent_id, config_file) {
        loader.inc()
        return postSubrepoAction(
            getSubRepoRow({ organization: owner, 
                            repository: repo, 
                            source_branch, 
                            target_branch, 
                            parent_full_name,
                            parent_id,
                            removeable: true,
                            source_repo_full_name: owner + "/" + repo,
                            config_file
                          })
                .then(res => $subRepos.append(res))
                .then(_ => $selectSubRepos.selectpicker('val',null))
        );
    }


    // adds the sub prs with same source branch as the meta pr to subRepos if they are not already there
    function addSubRepos() {
        let params = {
            organization: owner,
            repository: repository,
            source_branch: $('input[name="meta_repo\[source_branch\]"]').val(),
            target_branch: $('input[name="meta_repo\[target_branch\]"]').val(),
            pull_id: pr_id,
            source_repo_full_name: owner + "/" + repository,
            config_file: config_file
        };
        loader.inc();
        return postSubrepoAction(
            getSubRepos(params).then(_ => {
                // getSubRepos renders the _sub_repos template, which then renders a _sub_repo template for each sub repo
                // pass each _sub_repo, check if the row with sub repo id exists, if not add it to subRepos
                $(_).each(function(){
                    if(this instanceof HTMLTableRowElement) {                       
                        if(!hasExistingRow(this.getAttribute('id').replace("subrepos/", "")))
                            $subRepos.append(this);
                    }
                });
            })
        );
    }

    // sets sub prs to getSubRepoRow response(single table row)
    function updateSubRepo($row, params) {
        loader.inc();
        return postSubrepoAction(
            getSubRepoRow(params)
                .then(res => $row.replaceWith(res))
        );
    }

    // queries a single sub pull request row by id, calls updateSubRepo with found row
    function updateSubRepoRow() {
        const $this = $(this);
        const rowId = $this.data('id');
        const $row = $(document.getElementById(rowId));

        if ($row.length === 0) return

        const inputs = $.makeArray($row.find('[name^=sub_repos]'));
        let params = inputs.reduce((map, input) => {
            const match = input.getAttribute('name').match(/^sub_repos\[\]\[([^\]]+)\]/)
            if (!match) return map;

            map[match[1]] = input.value;
            return map;
        }, {});

        const addParams = { parent_full_name: owner+'/'+repository,
                            parent_id: pr_id
                          };
        params = Object.assign(addParams, params);
        return updateSubRepo($row, params);
    }

    // defines functions called after client request resolves
    function postSubrepoAction(promise) {
        return promise
            .then(_ => updateSaveAbleButton())
            .then(_ => setPageDirty())
            .then(_ => setTableVisibility($subRepoTable))
            .then(_ => initSelectpickers($('.show-selectpicker')))
            .then(_ => update_popovers())
            .then(_ => updateCheckboxes())
            .always(_ => loader.dec());
    }

    // get request for single sub pr
    function getSubRepoRow(params) {
        return $.get(`/view/${params.organization}/${params.repository}`, {
            data: params
        });
    }

    // get request for all sub prs
    function getSubRepos(params) {
        return $.get(`/view/${params.organization}/${params.repository}/find_all_sub_prs`, params);
    }
    
    updateSaveAbleButton();
    checkTitle();

});