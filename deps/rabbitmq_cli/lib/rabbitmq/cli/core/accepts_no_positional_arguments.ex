## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at https://mozilla.org/MPL/2.0/.
##
## Copyright (c) 2007-2025 Broadcom. All Rights Reserved. The term “Broadcom” refers to Broadcom Inc. and/or its subsidiaries.  All rights reserved.

# Should be used by commands that require rabbit app to be stopped
# but need no other execution environment validators.
defmodule RabbitMQ.CLI.Core.AcceptsNoPositionalArguments do
  defmacro __using__(_) do
    quote do
      def validate(args, _) when length(args) > 0 do
        {:validation_failure, :too_many_args}
      end

      # Note: this will accept everything, so it must be the
      # last validation clause defined!
      def validate(_, _), do: :ok
    end
  end
end
