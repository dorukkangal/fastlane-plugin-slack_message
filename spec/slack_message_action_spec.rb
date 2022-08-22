describe Fastlane::Actions::SlackMessageAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The slack_message plugin is working!")

      Fastlane::Actions::SlackMessageAction.run(nil)
    end
  end
end
