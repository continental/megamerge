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

function SearchSubRepos(search_branch) {
  $('#search_branch').disabled = true;
  $.ajax({
    url: '/do/search_subrepos',
    type: 'GET',
    dataType: 'text',
    data: {
      'search_branch': search_branch,
      'organization': organization,
      'repository': repository,
      'config_file': config_file,
    },
    success: function (responseData) {
      eval($(responseData).text());
    },
    complete: function (data) {
      ChangeLoadingCnt(-1);
    },

  });
  ChangeLoadingCnt(1);
}


function AddOrUpdateSubRepo(params) {

  var repoName = params['organization'] + '/' + params['repository'];

  $.ajax({
    url: '/view/' + repoName,
    type: 'GET',
    dataType: 'text',
    rowName: "subrepos/" + repoName,
    data: params,
    success: function (responseData) {
      NewSubRepoReceived(this.rowName, responseData);
    },
    complete: function (data) {
      ChangeLoadingCnt(-1);
    },

  });
  ChangeLoadingCnt(1);
}


function NewSubRepoReceived(name, data) {
  var newRowData = '<tr id="' + name + '" style="position:relative">' + data + '</tr>';

  if ($("tr[id='" + name + "']").length <= 0) // check if exists
    $('#subRepos').append(newRowData);
  else
    $("tr[id='" + name + "']").replaceWith(newRowData);

  $('#subRepos').parent().show();
  UpdateSaveAbleButton();
  select2_reload();
}


function UpdateSubRepoRow(name) {
  // extract all inputs in the subrepo row as {key: val}
  var parameters = {};
  $("tr[id='" + name + "'] [name^=sub_repos]").each(function () {
    var match = /sub_repos\[\]\[(.*)\]/g.exec($(this).attr('name'));
    if (match.length > 1)
      parameters[match[1]] = $(this).val();
  });

  AddOrUpdateSubRepo(parameters);
  ChangeWasDone();
}
