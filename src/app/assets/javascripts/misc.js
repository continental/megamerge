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

// run after page was loaded
$(document).ready(function() {

  // init popovers
  $(function () {
    $('[data-toggle="popover"]').popover( {
      trigger: 'hover',
      html: true
    })
  })

  // return if we dont have variables set (step1, step2 ... pages)
  if (typeof organization === 'undefined')
    return;


  select2_reload();

  $('#addSubRepoName').on('select2:select', function () {
    if($("tr[id='subrepos/"+organization+"/"+$('#addSubRepoName').val()+"']").length > 0)
      return;

    AddOrUpdateSubRepo({ organization: organization, repository: $('#addSubRepoName').val(), removeable: true});
    $('#addSubRepoName').val('');
    ChangeWasDone();
  })


  // make enter key work for search_branch
  $('#search_branch').keypress(function (e) {
    if (e.which == 13) { // enter
      SearchSubRepos($(this).val())
      return false;
    }
  });


});

function select2_reload() {
  // load all select 2
  $('.select2').select2({
    theme: 'bootstrap',
    dropdownAutoWidth : true,
  });


  $('#AddNewRepository').select2({
    theme: 'bootstrap',
    dropdownAutoWidth : true,
    ajax: {
      url: '/do/get_repositories/'+organization,
      dataType: 'json',
      cache: true
    }
  });
}

function DoMMAction(action) {
  window.location.href = "/do/"+action+"/"+organization+"/"+repository+"/"+pr_id;
}
