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

function AddSubRepoAction(params) {

  var action = params.action;
  var organization = params.organization;
  var repository = params.repository;
  var ref = params.ref;
  const done = params.done;

  if (ref == undefined)
    ref = "";

  var name = "subRepoActions" + organization + "/" + repository;

  var actionHtml = '';
  switch (action) {
    case 0:
      actionHtml += "Update existing Repository Hash";
      break;
    case 1:
      actionHtml += "Add new Repository by Hash";
      break;
    case 2:
      actionHtml += "Add new Repository by Branch";
      break;
    case 3:
      actionHtml += "Remove Repository";
      break;
  }
  actionHtml += '<input type="hidden" name="sub_repo_actions[][action]" value="' + action + '"';

  var refHtml = '';
  switch (action) {
    case 0:
    case 1:
      refHtml += '<div class="row">\
        <label class="col-sm-2 col-form-label">Hash: </label>\
          <div class="col-sm-10">\
            <input type="text" name="sub_repo_actions[][ref]" class="form-control" value="'+ ref + '" oninput="ChangeWasDone()">\
          </div>\
        </div>';
      break;
    case 2:
      refHtml += '<div class="row">\
        <label class="col-sm-2 col-form-label">Branch: </label>\
          <div class="col-sm-10">\
            <input type="text" name="sub_repo_actions[][ref]" class="form-control" value="'+ ref + '" disabled>\
          </div>\
        </div>';
      break;
    default:
      refHtml += '<input type="hidden" name="sub_repo_actions[][ref]">';
      break
  }

  var repositoryLink = github_base_url + '/' + organization + '/' + repository;

  var repositoryHtml = '<a href="' + repositoryLink + '">' + organization + '/' + repository + '</a>';
  repositoryHtml += '<input name="sub_repo_actions[][organization]" type="hidden" value="' + organization + '">';
  repositoryHtml += '<input name="sub_repo_actions[][repository]" type="hidden" value="' + repository + '">';

  // action
  var data = '<td class="text-center align-middle">' + actionHtml + '</td>';

  // repo name
  data += '<td class="align-middle">' + repositoryHtml + '</td>';

  // ref column
  data += '<td>' + refHtml + '</td>';

  if (!done) {
    // buttons at the end
    data += '<td class="text-right align-middle"> \
      <button type="button"\
       onclick="removeSubRepoAction($(this).parent().parent())"\
       class="btn btn-outline-danger btn-sm">\
        <span class="octicon octicon-x"></span> Remove\
      </button>\
    </td>';
  }

  var newRowData = '<tr id="' + name + '" style="position:relative">' + data + '</tr>';

  if ($("tr[id='" + name + "']").length <= 0) // check if exists
    $('#subRepoActions').append(newRowData);
  else
    $("tr[id='" + name + "']").replaceWith(newRowData);

  $('#subRepoActions').parent().fadeTo('fast', 1);
}


function removeSubRepoAction(row) {
  var tbody = row.parent();
  row.remove();
  if (tbody.children().length == 0)
    tbody.parent().hide();

  ChangeWasDone();
}
