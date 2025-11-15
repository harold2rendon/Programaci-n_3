# lib/trivia/question_bank.ex
defmodule Trivia.QuestionBank do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    questions = load_questions()
    Logger.info("Banco de preguntascargado con #{length(questions)} preguntas")
    {:ok, %{questions: questions}}
  end

  # API pública
  def get_question do
    GenServer.call(__MODULE__, :get_question)
  end

  def get_question_by_category(category) do
    GenServer.call(__MODULE__, {:get_question_by_category, category})
  end

  def get_questions_by_category(category, limit \\ nil) do
    GenServer.call(__MODULE__, {:get_questions_by_category, category, limit})
  end

  def get_categories do
    GenServer.call(__MODULE__, :get_categories)
  end

  # Callbacks del GenServer
  def handle_call(:get_question, _from, state) do
    questions = state.questions

    if Enum.empty?(questions) do
      {:reply, {:error, "No hay preguntas disponibles"}, state}
    else
      question = Enum.random(questions)
      {:reply, {:ok, question}, state}
    end
  end

  def handle_call({:get_question_by_category, category}, _from, state) do
    questions = Enum.filter(state.questions, fn q -> q.category == category end)

    if Enum.empty?(questions) do
      {:reply, {:error, "No hay preguntas disponibles para la categoría #{category}"}, state}
    else
      question = Enum.random(questions)
      {:reply, {:ok, question}, state}
    end
  end

  def handle_call({:get_questions_by_category, category, limit}, _from, state) do
    questions = Enum.filter(state.questions, fn q -> q.category == category end)

    result_questions =
      if limit do
        Enum.take(questions, limit)
      else
        questions
      end

    {:reply, result_questions, state}
  end

  def handle_call(:get_categories, _from, state) do
    categories =
      state.questions
      |> Enum.map(& &1.category)
      |> Enum.uniq()
      |> Enum.sort()

    {:reply, categories, state}
  end

  # Funciones privadas

  # Función para cargar preguntas desde el archivo
  defp load_questions do
    file_path = "data/questions.dat"

    case File.read(file_path) do
      {:ok, content} ->
        parse_questions(content)

      {:error, _reason} ->
        Logger.warning(
          "No se pudo cargar el archivo de preguntas, usando preguntas predeterminadas"
        )

        default_questions()
    end
  end

  # Función para analizar el contenido del archivo de preguntas
  defp parse_questions(content) do
    content
    |> String.split("\n")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn line ->
      case String.split(line, "|") do
        [category, question, correct, wrong1, wrong2, wrong3] ->
          %{
            category: String.trim(category),
            question: String.trim(question),
            correct_answer: String.trim(correct),
            all_answers:
              Enum.shuffle([
                String.trim(correct),
                String.trim(wrong1),
                String.trim(wrong2),
                String.trim(wrong3)
              ])
          }

        _ ->
          nil
      end
    end)
    |> Enum.filter(& &1)
  end

  # Preguntas predeterminadas en caso de fallo al cargar el archivo
  defp default_questions do
    [
      %{
        category: "Ciencia",
        question: "¿Cuál es el planeta más grande del sistema solar?",
        correct_answer: "Júpiter",
        all_answers: ["Júpiter", "Saturno", "Neptuno", "Tierra"]
      },
      %{
        category: "Ciencia",
        question: "¿Qué gas necesitan las plantas para la fotosíntesis?",
        correct_answer: "Dióxido de carbono",
        all_answers: ["Dióxido de carbono", "Oxígeno", "Nitrógeno", "Hidrógeno"]
      },
      %{
        category: "Historia",
        question: "¿En qué año llegó Colón a América?",
        correct_answer: "1492",
        all_answers: ["1492", "1502", "1488", "1510"]
      },
      %{
        category: "Historia",
        question: "¿Quién pintó la Mona Lisa?",
        correct_answer: "Leonardo da Vinci",
        all_answers: ["Leonardo da Vinci", "Pablo Picasso", "Vincent van Gogh", "Miguel Ángel"]
      },
      %{
        category: "Deportes",
        question: "¿En qué deporte se usa una raqueta?",
        correct_answer: "Tenis",
        all_answers: ["Tenis", "Fútbol", "Baloncesto", "Natación"]
      },
      %{
        category: "Deportes",
        question: "¿Cuántos jugadores hay en un equipo de fútbol?",
        correct_answer: "11",
        all_answers: ["11", "9", "7", "13"]
      },
      %{
        category: "Geografía",
        question: "¿Cuál es el río más largo del mundo?",
        correct_answer: "Amazonas",
        all_answers: ["Amazonas", "Nilo", "Misisipi", "Yangtsé"]
      },
      %{
        category: "Geografía",
        question: "¿Cuál es la capital de Francia?",
        correct_answer: "París",
        all_answers: ["París", "Londres", "Berlín", "Madrid"]
      },
      %{
        category: "Arte",
        question: "¿Quién compuso la Novena Sinfonía?",
        correct_answer: "Beethoven",
        all_answers: ["Beethoven", "Mozart", "Bach", "Chopin"]
      },
      %{
        category: "Arte",
        question: "¿Qué artista pintó 'La noche estrellada'?",
        correct_answer: "Van Gogh",
        all_answers: ["Van Gogh", "Picasso", "Dalí", "Monet"]
      }
    ]
  end
end
