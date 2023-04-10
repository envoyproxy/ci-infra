// Functions that assist when filtering through AMIs.

// Determines whether the AMI and its snapshots should be cleaned by this
// script based on the tags it has.
exports.isAmiInScopeFromTags = function (tags) {
  let has_in_scope_project_tag = false;
  tags.forEach((tagObj) => {
    if (tagObj['Key'] != 'Project') {
      return;
    }

    if (tagObj['Value'].indexOf('envoy-azp-') == 0) {
      has_in_scope_project_tag = true;
    } else if (tagObj['Value'].indexOf('Salvo') == 0) {
      has_in_scope_project_tag = true;
    }
  });
  return has_in_scope_project_tag;
};
