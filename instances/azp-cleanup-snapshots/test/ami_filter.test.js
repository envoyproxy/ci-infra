const expect = require('chai').expect;
const ami_filter = require('../ami_filter');

describe('isAmiInScopeFromTags unit test)', function () {
  it('should return false for empty tags', function () {
    const tags = [];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(false);
  });

  it('should return false for non Project tags', function () {
    const tag = new Object();
    tag.Key = 'non Project';
    const tags = [tag];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(false);
  });

  it('should return true for envoy-azp-arm64 AMIs', function () {
    const tag = new Object();
    tag.Key = 'Project';
    tag.Value = 'envoy-azp-arm64';
    const tags = [tag];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(true);
  });

  it('should return true for envoy-azp-x64 AMIs', function () {
    const tag = new Object();
    tag.Key = 'Project';
    tag.Value = 'envoy-azp-x64';
    const tags = [tag];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(true);
  });

  it('should return true for all Salvo AMIs', function () {
    const tag = new Object();
    tag.Key = 'Project';
    tag.Value = 'Salvo';
    const tags = [tag];
    expect(ami_filter.isAmiInScopeFromTags(tags)).to.equal(true);
  });
});
