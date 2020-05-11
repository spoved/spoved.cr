abstract class Spoved::DB::Model
  abstract def logger

  abstract def _insert_record
  abstract def _delete_record
  abstract def _update_record

  def save!
    self._insert_record
  end

  def save
    save!
  rescue ex
    logger.error { ex }
  end

  def destroy!
    self._delete_record
  end

  def destroy
    destroy!
  rescue ex
    logger.error { ex }
  end

  def update!
    self._update_record
  end

  def update
    update!
  rescue ex
    logger.error { ex }
  end

  # Queries for all records and yields each one
  def self.each(&block)
    self.all do |x|
      yield x
    end
  end
end
