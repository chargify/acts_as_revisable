require 'spec_helper'

describe WithoutScope::ActsAsRevisable do
  after(:each) do
    cleanup_db
  end

  describe "with a single revision" do
    before(:each) do
      @project1 = Project.create(:name => "Rich", :notes => "a note")
      @project1.update_attribute(:name, "Sam")
    end

    it "should just find the current revision by default" do
      Project.find(:first).name.should == "Sam"
    end

    it "should accept the with_revisions chain method" do
      lambda { Project.scoped.with_revisions }.should_not raise_error
    end

    it "should find current and revisions with the with_revisions chain method" do
      Project.scoped.with_revisions.size.should == 2
    end

    it "should find revisions with conditions" do
      Project.where(:name => "Rich").with_revisions.should == [@project1.find_revision(:previous)]
    end

		it "should find last revision" do
			@project1.find_revision(:last).should == @project1.find_revision(:previous)
		end
  end
end
