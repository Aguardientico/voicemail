require 'spec_helper'

describe Voicemail::MailboxSetGreetingController do
  include VoicemailControllerSpecHelper

  describe '#section_menu' do
    it 'calls #menu with the proper parameters' do
      ['listen_to_current', 'record_new', 'delete_greeting'].each do |prompt|
        subject.should_receive(:t).with("voicemail.set_greeting.greeting_menu.#{prompt}").and_return prompt
      end
      subject.should_receive(:t).with('voicemail.return_to_main_menu').and_return 'main_menu'
      subject.should_receive(:menu).once.with(['listen_to_current', 'record_new', 'delete_greeting', 'main_menu'],
          { timeout: config.menu_timeout,
            tries: config.menu_tries }, Proc)
      controller.section_menu
    end
  end

  describe '#listen_to_current_greeting' do
    context 'without a greeting message' do
      it 'plays the default greeting if one is not specified' do
        subject.should_receive(:t).with('voicemail.set_greeting.no_personal_greeting').and_return 'no_personal_greeting'
        should_play 'no_personal_greeting'
        subject.should_receive(:section_menu).once.and_return(true)
        controller.listen_to_current_greeting
      end
    end

    context 'with a specified greeting message' do
      let(:greeting) { 'Howdy!' }

      it 'plays the specific greeting message' do
        should_play greeting
        subject.should_receive(:section_menu).once.and_return(true)
        controller.listen_to_current_greeting
      end
    end
  end

  describe '#record_greeting' do
    let(:recording_component) { flexmock 'Record' }
    let(:file_path) { '/path/to/file' }

    before do
      subject.should_receive(:t).with('voicemail.set_greeting.recording_instructions').and_return 'recording_instructions'
      subject.should_receive(:t).with('voicemail.return_to_main_menu').and_return 'main_menu'
      ['save_greeting', 'discard_greeting'].each do |prompt|
        subject.should_receive(:t).with("voicemail.set_greeting.recording_menu.#{prompt}").and_return prompt
      end
      should_play 'recording_instructions'
      recording_component.should_receive('complete_event.recording.uri').and_return file_path
      subject.should_receive(:play_audio).with file_path
      subject.should_receive(:menu).once.with ['save_greeting', 'discard_greeting', 'main_menu'],
                                              { timeout: config.menu_timeout, tries: config.menu_tries }, Proc
    end

    after do
      controller.record_greeting
      config.use_mailbox_opts_for_recording = false
    end

    context 'without mailbox settings' do
      it 'plays the appropriate sounds, records, plays back recording, and calls the recording menu' do
        subject.should_receive(:record).once.with(config.recording.to_hash).and_return recording_component
      end
    end

    context 'with mailbox settings' do
      let(:mailbox) { {id: 100, record_options: {final_timeout: 31}} }

      before { config.use_mailbox_opts_for_recording = true }

      it "records using the mailbox's record options" do
        expected_options = {direction: :send, final_timeout: 31, interruptible: true, max_duration: 30, start_beep: true, stop_beep: false}
        subject.should_receive(:record).once.with(expected_options).and_return recording_component
      end
    end
  end

  describe '#delete_greeting_menu' do
    it 'calls #menu with proper parameters' do
      subject.should_receive(:t).with('voicemail.set_greeting.delete_confirmation').and_return 'delete_confirmation'
      subject.should_receive(:t).with('voicemail.press_one_to_confirm').and_return 'press_one_to_confirm'
      subject.should_receive(:t).with('voicemail.return_to_main_menu').and_return 'main_menu'
      subject.should_receive(:menu).once.with(['delete_confirmation', 'press_one_to_confirm', 'main_menu'],
         {timeout: config.menu_timeout,
          tries: config.menu_tries}, Proc)
      subject.delete_greeting_menu
    end
  end

  describe '#delete_greeting' do
    it "deletes the greeting and plays a confirmation" do
      subject.should_receive(:t).with('voicemail.set_greeting.greeting_deleted').and_return 'greeting_deleted'
      storage_instance.should_receive(:delete_greeting_from_mailbox).with(mailbox[:id])
      subject.should_receive(:play).with('greeting_deleted')
      subject.should_receive(:main_menu)
      subject.delete_greeting
    end
  end

  describe '#save_greeting' do
    let(:file_path) { '/path/to/file' }

    it 'saves the greeting and goes to the main menu' do
      subject.should_receive(:temp_recording).once.and_return(file_path)
      storage_instance.should_receive(:save_greeting_for_mailbox).with(mailbox[:id], file_path)
      subject.should_receive(:main_menu)
      controller.save_greeting
    end
  end
end
