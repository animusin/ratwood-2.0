import React, { useEffect, useState } from 'react';
import {
  Box,
  Button,
  NoticeBox,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  body: string;
  maxlen: number;
  body_len: number;
  needs_import_confirm: boolean;
};

export const PaperWriterPanel = () => {
  const { act, data } = useBackend<Data>();
  const { body: initialBody, maxlen, needs_import_confirm } = data;
  const [body, setBody] = useState(initialBody || '');

  useEffect(() => {
    setBody(initialBody || '');
  }, [initialBody]);

  const remaining = Math.max(0, maxlen - body.length);

  return (
    <Window width={760} height={620} title="Letter Editor">
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Writing">
              <NoticeBox>
                Supports existing paper formatting: # headers, **bold**, *italics*, ^size^,
                %s signature, %f field, and -=RRGGBBtext=- color blocks.
              </NoticeBox>
              {!!needs_import_confirm && (
                <NoticeBox danger mt={1}>
                  This letter was imported from existing formatted text. Saving may simplify older
                  formatting details. Use Save Anyway to confirm overwrite.
                </NoticeBox>
              )}
              <Box mt={1} mb={1} color={remaining < 50 ? 'bad' : 'label'}>
                Characters: {body.length}/{maxlen}
              </Box>
              <TextArea
                height="360px"
                width="100%"
                value={body}
                onChange={(value: string) => setBody(value)}
                placeholder="Write your letter..."
              />
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Stack>
              <Stack.Item>
                <Button
                  color="good"
                  icon="save"
                  onClick={() => act('save', { body, force: 0 })}>
                  Save
                </Button>
              </Stack.Item>
              {!!needs_import_confirm && (
                <Stack.Item>
                  <Button
                    color="average"
                    icon="exclamation-triangle"
                    onClick={() => act('save', { body, force: 1 })}>
                    Save Anyway
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item>
                <Button
                  color="average"
                  icon="eraser"
                  onClick={() => {
                    setBody('');
                    act('clear');
                  }}>
                  Clear
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="bad"
                  icon="times"
                  onClick={() => act('close')}>
                  Close
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
