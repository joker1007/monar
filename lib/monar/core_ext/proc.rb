class Proc
  def apply_as(applicative_class, *args)
    applicative_class.pure(self).ap(*args)
  end
end
