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

$('.merge.step4').ready(function () {
    $('#file-select').selectpicker({
    
    });

    const data = $('#data').data();
    $('#continue').on('click', function () {
        window.location.pathname =
            `/create/${data.organization}/${data.repository}/${encodeURIComponent(data.source_branch)}/${encodeURIComponent(data.target_branch)}/${$('#file-select').val()}`;
    });
});