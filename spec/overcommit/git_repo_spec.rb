require 'spec_helper'

describe Overcommit::GitRepo do
  describe '.list_files' do
    let(:paths) { [] }
    let(:options) { {} }
    subject { described_class.list_files(paths, options) }

    around do |example|
      repo do
        `git commit --allow-empty -m "Initial commit"`
        example.run
      end
    end

    context 'when path includes a submodule directory' do
      let(:submodule_dir) { 'sub-repo' }

      before do
        submodule = repo do
          `git commit --allow-empty -m "Submodule commit"`
        end

        `git submodule add #{submodule} #{submodule_dir} 2>&1 > #{File::NULL}`
        `git commit -m "Add submodule"`
      end

      it { should_not include(File.expand_path(submodule_dir)) }
    end

    context 'when listing contents of a directory' do
      let(:dir) { 'some-dir' }
      let(:paths) { [dir + File::SEPARATOR] }

      before do
        FileUtils.mkdir(dir)
      end

      context 'when directory is empty' do
        it { should be_empty }
      end

      context 'when directory contains a file' do
        let(:file) { "#{dir}/file" }

        before do
          FileUtils.touch(file)
          `git add "#{file}"`
          `git commit -m "Add file"`
        end

        context 'when path contains no spaces' do
          it { should include(File.expand_path(file)) }
        end

        context 'when path contains spaces' do
          let(:dir) { 'some dir' }

          it { should include(File.expand_path(file)) }
        end
      end
    end
  end

  describe '.staged_submodule_removals' do
    subject { described_class.staged_submodule_removals }

    around do |example|
      submodule = repo do
        `git commit --allow-empty -m "Submodule commit"`
      end

      repo do
        `git submodule add #{submodule} sub-repo 2>&1 > #{File::NULL}`
        `git commit -m "Initial commit"`
        example.run
      end
    end

    context 'when there are no submodule removals staged' do
      it { should be_empty }
    end

    context 'when there are submodule additions staged' do
      before do
        another_submodule = repo do
          `git commit --allow-empty -m "Another submodule"`
        end

        `git submodule add #{another_submodule} another-sub-repo 2>&1 > #{File::NULL}`
      end

      it { should be_empty }
    end

    context 'when there is one submodule removal staged' do
      before do
        `git rm sub-repo`
      end

      it 'returns the submodule that was removed' do
        subject.size.should == 1
        subject.first.tap do |sub|
          sub.path.should == 'sub-repo'
          File.directory?(sub.url).should == true
        end
      end
    end

    context 'when there are multiple submodule removals staged' do
      before do
        another_submodule = repo do
          `git commit --allow-empty -m "Another submodule"`
        end

        `git submodule add #{another_submodule} yet-another-sub-repo 2>&1 > #{File::NULL}`
        `git commit -m "Add yet another submodule"`
        `git rm sub-repo`
        `git rm yet-another-sub-repo`
      end

      it 'returns all submodules that were removed' do
        subject.size.should == 2
        subject.map(&:path).sort.should == ['sub-repo', 'yet-another-sub-repo']
      end
    end
  end

  describe '.branches_containing_commit' do
    subject { described_class.branches_containing_commit(commit_ref) }

    around do |example|
      repo do
        `git checkout -b master > #{File::NULL} 2>&1`
        `git commit --allow-empty -m "Initial commit"`
        `git checkout -b topic > #{File::NULL} 2>&1`
        `git commit --allow-empty -m "Another commit"`
        example.run
      end
    end

    context 'when only one branch contains the commit' do
      let(:commit_ref) { 'topic' }

      it 'should return only that branch' do
        subject.size.should == 1
        subject[0].should == 'topic'
      end
    end

    context 'when more than one branch contains the commit' do
      let(:commit_ref) { 'master' }

      it 'should return all branches containing the commit' do
        subject.size.should == 2
        subject.sort.should == %w[master topic]
      end
    end

    context 'when no branches contain the commit' do
      let(:commit_ref) { 'HEAD' }

      before do
        `git checkout --detach > #{File::NULL} 2>&1`
        `git commit --allow-empty -m "Detached HEAD"`
      end

      it { should be_empty }
    end
  end
end
