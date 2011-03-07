require File.join(File.dirname(__FILE__), "test_helper")
require "event_handler"

class EventHandlerTest < Test::Unit::TestCase
  def stub_keymap(keymap)
    KeyMap.stubs(:user_keymap).returns(keymap)
  end

  def setup
    @event_handler = EventHandler.new
    @event_handler.current_mode = :command
  end

  context "when handling keydown events" do
    setup do
      stub_keymap({ :insert => { "h" => "move_backward" } })
    end

    should "respond with the correct command from the user's keymap" do
      @event_handler.current_mode = :insert
      assert_equal ["moveBackward:"], type_key("h")
    end

    should "transition to insert mode from command mdoe" do
      @event_handler.current_mode = :command
      stub_keymap(:command => { "i" => "insert_backward" })
      type_key "i"
      assert_equal :insert, @event_handler.current_mode
    end

    should "transition to command mode from insert mode" do
      @event_handler.current_mode = :insert
      stub_keymap(:insert => { "<esc>" => "enter_command_mode" })
      type_key "\e"
      assert_equal :command, @event_handler.current_mode
    end

    should "transition to visual mode from command mode" do
      @event_handler.current_mode = :command
      stub_keymap(:command => { "v" => "enter_visual_mode" })
      type_key "v"
      assert_equal :visual, @event_handler.current_mode
    end

    context "passing through keystrokes" do
      should "not let unbound keys pass through in command mode" do
        @event_handler.current_mode = :command
        stub_keymap(:command => {})
        assert_equal ["noOp"], type_key("v")
      end

      should "let unbound keys with the CMD modifier pass through in command mode" do
        @event_handler.current_mode = :command
        stub_keymap(:command => {})
        assert_equal [], type_key("<M-c>")
      end

      should "let unbound keys pass through in insert mode" do
        @event_handler.current_mode = :insert
        stub_keymap(:insert => {})
        assert_equal [], type_key("v")
      end
    end

    should "execute multiple commands if more than one is specified as the target of a user's key mapping" do
      stub_keymap(:command => { "q" => ["move_forward", "move_backward"] })
      assert_equal ["moveForward:", "moveBackward:"], type_key("q")
    end

    should "queue up keystrokes and execute commands composed of multiple keystrokes" do
      stub_keymap(:command => { "gg" => "move_to_beginning_of_document" })
      # The first key should result in a noOp, because it might turn out to be part of the "gg" command.
      assert_equal ["noOp"], type_key("g")
      assert_equal ["moveToBeginningOfDocument:"], type_key("g")
      assert_equal [], @event_handler.key_queue
    end
  end

  context "get_keybindings" do
    should "return a list of all registered keybindings across all modes" do
      stub_keymap(:command => { "<C-y>" => "first command" }, :insert => { "Q" => "second command" })
      result = @event_handler.handle_message({ :message => "getKeybindings" }.to_json)
      assert_equal [["y", KeyStroke::ControlKeyMask], ["Q", 0]], result
    end
  end

  context "keymap" do
    should "parse out multiple keystrokes from a string" do
      assert_equal "x<C-M-y>Z", KeyMap.keystrokes_from_string("x<M-C-y>Z").map(&:to_s).join
    end
  end

  def type_key(key_string)
    keystroke = KeyStroke.from_string(key_string)
    @event_handler.handle_message({
      :message => "keydown",
      :characters => keystroke.key,
      :modifierFlags => keystroke.modifier_flags }.to_json)
  end
end