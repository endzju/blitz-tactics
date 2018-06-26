class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :validatable,
  # :recoverable, and :omniauthable

  devise :database_authenticatable, :registerable, :rememberable,
         :trackable, :validatable

  has_many :level_attempts
  has_many :solved_infinity_puzzles
  has_many :completed_speedruns
  has_many :completed_repetition_rounds
  has_many :completed_repetition_levels
  has_many :positions

  after_initialize :set_default_profile

  validate :validate_username

  def self.find_for_database_authentication(conditions)
    if conditions.has_key?(:username)
      username = conditions[:username].downcase
      where("LOWER(username) = ?", username).first
    end
  end

  # infinity puzzle methods

  def latest_difficulty
    solved_infinity_puzzles.last&.difficulty || 'easy'
  end

  def infinity_puzzles_after(difficulty, puzzle_id)
    InfinityLevel
      .find_by(difficulty: difficulty)
      .puzzles_after_id(puzzle_id || last_solved_infinity_puzzle_id(difficulty))
  end

  def last_solved_infinity_puzzle_id(difficulty)
    solved_infinity_puzzles.with_difficulty(difficulty).last&.infinity_puzzle_id
  end

  def next_infinity_puzzle
    infinity_puzzles_after(
      latest_difficulty,
      last_solved_infinity_puzzle_id(latest_difficulty)
    ).first || InfinityLevel.find_by(difficulty: latest_difficulty).last_puzzle
  end

  def num_infinity_puzzles_solved
    solved_infinity_puzzles.count
  end

  def infinity_puzzles_solved_by_difficulty
    InfinityLevel::DIFFICULTIES.map do |difficulty|
      [
        difficulty,
        solved_infinity_puzzles.where(difficulty: difficulty).count
      ]
    end
  end

  # speedrun mode methods
  def num_speedruns_completed
    @num_speedruns_completed ||= completed_speedruns.count
  end

  def best_speedrun_time
    completed_speedruns.formatted_fastest_time
  end

  def speedrun_stats
    SpeedrunLevel.all.map do |level|
      [
        level.name,
        completed_speedruns.formatted_personal_best(level.id)
      ]
    end
  end

  # old repetition mode methods

  def num_repetition_levels_unlocked
    Set.new(self.profile["levels_unlocked"]).count
  end

  # new repetition mode methods

  def highest_repetition_level_number_completed
    completed_repetition_levels
      .includes(:repetition_level)
      .joins(:repetition_level)
      .order('repetition_levels.number desc')
      .first&.repetition_level&.number || 0
  end

  def highest_repetition_level_unlocked
    RepetitionLevel.number(highest_repetition_level_number_completed + 1)
  end

  def round_times_for_level_id(repetition_level_id)
    completed_repetition_rounds
      .where(repetition_level_id: repetition_level_id)
      .order(id: :desc)
      .limit(10)
      .map(&:formatted_time_spent)
  end

  private

  def email_required?
    false
  end

  def set_default_profile
    self.profile ||= {
      "levels_unlocked": [1]
    }
  end

  def validate_username
    unless username =~ /\A[a-z]/i
      errors.add :username, "must start with a letter"
    end
    unless username =~ /\A[a-z][a-z0-9_]{2,}\Z/i
      errors.add :username, "must be at least 3 letters, numbers, or underscores"
    end
    if username.length > 32
      errors.add :username, "is too long"
    end
    return unless new_record?
    if User.where("LOWER(username) = ?", username.downcase).count > 0
      errors.add :username, "is already registered"
    end
  end
end
