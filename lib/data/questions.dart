class Question {
  final String question;
  final List<String> answers;
  final int correct;

  const Question({
    required this.question,
    required this.answers,
    required this.correct,
  });
}

const List<Question> stage1Questions = [
  Question(
    question: "Кто моя любимая?",
    answers: ["Нурсауле", "Аруана", "Одноклассница", "Какая-то девочка"],
    correct: 0,
  ),

  Question(
    question: "Наше первое знакомство?",
    answers: ["25.06", "02.07", "01.07", "28.06"],
    correct: 0,
  ),

  Question(
    question: "Что мне в тебе нравится?",
    answers: ["Улыбка", "Глаза", "Внешность", "Вся ты"],
    correct: 3,
  ),

  Question(
    question: "Моё любимое блюдо?",
    answers: ["Манты", "Плов", "То, что ты приготовишь", "Шавуха"],
    correct: 2,
  ),

  Question(
    question: "Каким спортом я занимался?",
    answers: ["Баскетбол", "Каратэ", "Не занимался", "Дзюдо"],
    correct: 3,
  ),

  Question(
    question: "За что я тебя полюбил?",
    answers: ["За глаза", "За заботу", "За фигуру", "За деньги"],
    correct: 1,
  ),

  Question(
    question: "Где я жил?",
    answers: ["В Алматы", "В Астане", "В Караганде", "В подъезде"],
    correct: 0,
  ),

  Question(
    question: "Столица Венгрии?",
    answers: ["Будапешт", "Париж", "Вена", "Анкара"],
    correct: 0,
  ),

  Question(
    question: "Моя дата рождения?",
    answers: ["27.09", "23.09", "28.09", "25.09"],
    correct: 2,
  ),

  Question(
    question: "Куда я поступлю?",
    answers: ["В Астану", "В Китай", "В Алматы", "В Караганду"],
    correct: 1,
  ),
];

const List<Question> stage2Questions = [
  Question(
    question: "Мне нравятся другие?",
    answers: ["Нет", "Да"],
    correct: 0,
  ),

  Question(
    question: "Скучаю ли я по тебе?",
    answers: ["Нет", "Да"],
    correct: 1,
  ),

  Question(
    question: "Волнуюсь ли я за тебя?",
    answers: ["Нет", "Да"],
    correct: 1,
  ),

  Question(
    question: "Смотрю ли я на других?",
    answers: ["Нет", "Да"],
    correct: 0,
  ),

  Question(
    question: "Брошу ли я тебя если мне плохо?",
    answers: ["Нет", "Да"],
    correct: 0,
  ),

  Question(
    question: "Нужны ли мне другие?",
    answers: ["Нет", "Да"],
    correct: 0,
  ),

  Question(question: "Люблю ли я тебя?", answers: ["Нет", "Да"], correct: 1),

  Question(
    question: "Кину ли я всех ради тебя?",
    answers: ["Нет", "Да"],
    correct: 1,
  ),

  Question(
    question: "Сделаю тебя счастливой?",
    answers: ["Нет", "Конечно ❤️"],
    correct: 1,
  ),

  Question(
    question: "Рад ли я что нашёл тебя?",
    answers: ["Нет", "Да"],
    correct: 1,
  ),
];
