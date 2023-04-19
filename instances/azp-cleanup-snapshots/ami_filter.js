// Functions that assist when filtering through AMIs.

/**
 * Determines whether the AMI and its snapshots should be cleaned by this
 * Lambda based on the tags it has.
 * @param tags - an array of all the tags attached to the AMI.
 * @returns {boolean} - true if the AMI is in scope and should be cleaned up.
 * False otherwise. Note that the Lambda only cleans up the AMI if unused.
**/
exports.isAmiInScopeFromTags = (tags) => {
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
