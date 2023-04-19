const expect = require('chai').expect;
const ami_filter = require('../ami_filter');

// Creates an array of AMI tags with a single tag whose Project value is set to
// the argument project.
function createAmiTagsWithProject(project) {
    const tag = new Object();
    tag.Key = 'Project';
    tag.Value = project;

    return new Array(tag);
}

describe('isAmiInScopeFromTags unit test)', () => {
  it('should return false for empty tags', () => {
    const tags = [];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(false);
  });

  it('should return false for non Project tags', () => {
    const tag = new Object();
    tag.Key = 'non Project';
    const tags = [tag];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(false);
  });

  it('should return false for an out of scope value', () => {
    const tags = createAmiTagsWithProject('something');
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(false);
  });

  it('should return true for envoy-azp-arm64 AMIs', () => {
    const tags = createAmiTagsWithProject('envoy-azp-arm64');
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(true);
  });

  it('should return true for envoy-azp-x64 AMIs', () => {
    const tags = createAmiTagsWithProject('envoy-azp-x64');
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(true);
  });

  it('should return true for all Salvo AMIs', () => {
    const tags = createAmiTagsWithProject('Salvo');
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(true);
  });
});
