# test/trivia/user_manager_test.exs
defmodule Trivia.UserManagerTest do
  use ExUnit.Case
  alias Trivia.UserManager

  setup do
    # Usar archivo temporal para pruebas
    test_file = "test/data/test_users.dat"
    File.write!(test_file, "")

    # Iniciar UserManager con archivo de prueba
    {:ok, pid} = GenServer.start_link(UserManager, %{}, name: UserManager)
    {:ok, pid: pid, test_file: test_file}
  end

  test "register_user/2 creates new user successfully", %{test_file: test_file} do
    assert {:ok, message} = UserManager.register_user("newuser", "password123")
    assert String.contains?(message, "newuser")

    # Verificar que se guardó en archivo
    content = File.read!(test_file)
    assert String.contains?(content, "newuser")
  end

  test "register_user/2 rejects duplicate usernames" do
    assert {:ok, _} = UserManager.register_user("duplicate", "pass1")
    assert {:error, "El usuario ya existe"} = UserManager.register_user("duplicate", "pass2")
  end

  test "login_user/2 works with valid credentials" do
    UserManager.register_user("validuser", "correctpass")
    assert {:ok, session_id, user} = UserManager.login_user("validuser", "correctpass")
    assert is_binary(session_id)
    assert user.username == "validuser"
  end

  test "login_user/2 fails with invalid credentials" do
    UserManager.register_user("testuser", "mypass")
    assert {:error, "Contraseña incorrecta"} = UserManager.login_user("testuser", "wrongpass")
    assert {:error, "Usuario no encontrado"} = UserManager.login_user("nonexistent", "anypass")
  end

  test "get_user_by_session/1 returns user for valid session" do
    {:ok, session_id, user} = UserManager.login_user("sessionuser", "pass")
    assert {:ok, retrieved_user} = UserManager.get_user_by_session(session_id)
    assert retrieved_user.username == user.username
  end

  test "get_user_by_session/1 fails for invalid session" do
    assert {:error, "Sesión no válida"} = UserManager.get_user_by_session("invalid_session")
  end

  test "update_user_score/3 updates user statistics" do
    UserManager.register_user("scoreuser", "pass")
    assert {:ok, updated_user} = UserManager.update_user_score("scoreuser", 50, "Science")
    assert updated_user.score == 50
    assert updated_user.games_played == 1
  end

  test "get_leaderboard/0 returns sorted users by score" do
    UserManager.register_user("lowscore", "pass")
    UserManager.register_user("highscore", "pass")
    UserManager.update_user_score("lowscore", 25, "History")
    UserManager.update_user_score("highscore", 75, "Science")

    leaderboard = UserManager.get_leaderboard()
    assert length(leaderboard) >= 2
    assert hd(leaderboard).score == 75
  end

  test "logout_user/1 removes session" do
    {:ok, session_id, _} = UserManager.login_user("logoutuser", "pass")
    assert :ok = UserManager.logout_user(session_id)
    assert {:error, "Sesión no válida"} = UserManager.get_user_by_session(session_id)
  end
end
