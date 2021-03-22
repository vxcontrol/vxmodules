<template>
  <div>
    <el-tabs tab-position="left" v-model="leftTab">
      <el-tab-pane name="code" :label="locale[$i18n.locale]['code']">
        <div id="container" class="editor"></div>
        <br>
        <p class="uk-margin buttons">
          <el-button type="primary" @click="execCode"
          >{{ locale[$i18n.locale]['buttonExec'] }}</el-button>
          <el-button @click="saveSnippet"
          >{{ locale[$i18n.locale]['buttonSave'] }}</el-button>
          <el-button @click="loadSnippet"
          >{{ locale[$i18n.locale]['buttonLoad'] }}</el-button>
        </p>
        <el-tabs v-model="bottomTab">
          <el-tab-pane :label="locale[$i18n.locale]['output']" name="output">
            <pre style="min-height:30px">{{ response_out }}</pre>
          </el-tab-pane>
          <el-tab-pane :label="locale[$i18n.locale]['errors']" name="errors">
            <pre style="min-height:30px">{{ response_err }}</pre>
          </el-tab-pane>
        </el-tabs>
      </el-tab-pane>
      <el-tab-pane name="events" :label="$t('BrowserModule.Page.TabTitle.Events')">
        <component
          :is="components['eventsTable']"
          :module-name="name"
          :agent-events="eventsAPI"
          :agent-modules="modulesAPI"
        ></component>
      </el-tab-pane>
      <el-tab-pane name="config" :label="$t('BrowserModule.Page.TabTitle.Config')">
        <component
          :is="components['agentModuleConfig']"
          :module="module"
        ></component>
      </el-tab-pane>
    </el-tabs>

    <vk-notification status="primary" :messages.sync="messages"></vk-notification>
  </div>
</template>

<script>
const name = "lua-interpreter";

module.exports = {
  name,
  props: ["protoAPI", "hash", "module", "eventsAPI", "modulesAPI", "components"],
  data: () => ({
    name,
    leftTab: "code",
    bottomTab: "output",
    connection: {},
    messages: [],
    response_out: "",
    response_err: "",
    editor: null,
    locale: {
      ru: {
        code: "Редактор кода",
        buttonExec: "Выполнить",
        buttonSave: "Сохранить",
        buttonLoad: "Загрузить",
        output: "Результат",
        errors: "Ошибки",
        connected: "подключен",
        recvError: "Ошибка при выполнении"
      },
      en: {
        code: "Editor",
        buttonExec: "Execute",
        buttonSave: "Save",
        buttonLoad: "Load",
        output: "Output",
        errors: "Errors",
        connected: "connected",
        recvError: "Error on execute"
      }
    }
  }),
  created() {
    this.protoAPI.connect().then(
      connection => {
        const date = new Date().toLocaleTimeString();
        this.connection = connection;
        this.connection.subscribe(this.recvData, "data");
        this.messages.push({
          message: `${date} ${this.locale[this.$i18n.locale]['connected']}`,
          status: "success"
        });
      },
      error => console.log(error)
    );
  },
  mounted() {
    if (!this.editor) {
      let code = 'print("Hello world!")';
      if (localStorage.getItem("lastState")) {
        code = localStorage.getItem("lastState");
      }
      const cntr = document.getElementById("container");
      this.editor = this.components.monaco.editor.create(cntr, {
        value: code,
        language: "lua"
      });
      const KM = this.components.monaco.KeyMod;
      const KC = this.components.monaco.KeyCode;
      this.editor.addCommand(KM.CtrlCmd | KC.Enter, this.execCode);
      this.editor.addCommand(KM.CtrlCmd | KC.KEY_S, this.saveSnippet);
      this.editor.addCommand(KM.CtrlCmd | KC.KEY_O, this.loadSnippet);
    }
  },
  methods: {
    recvData(msg) {
      let data = new TextDecoder("utf-8").decode(msg.content.data);
      let decoded_response = JSON.parse(data);
      if (decoded_response.output) {
        this.response_out = decoded_response.output;
        this.bottomTab = "output";
      }
      if (decoded_response.err) {
        this.response_err = decoded_response.err;
        this.bottomTab = "errors";
        this.messages.push({
          message: this.locale[this.$i18n.locale]['recvError'],
          status: "error"
        });
      }

      if (decoded_response.status) {
      } else {
        if (decoded_response.ret) {
          this.response_err += decoded_response.ret;
        }
      }
    },
    execCode() {
      this.response_out = "";
      this.response_err = "";
      const model = this.editor.getModel();
      const value = model.getValue();
      let safe_value = value.replace("\r", "\r");
      safe_value = safe_value.replace("\n", "\n");
      let data = JSON.stringify({ type: "exec", code: safe_value });
      this.connection.sendData(data);
    },
    saveSnippet() {
      const model = this.editor.getModel();
      const value = model.getValue();
      localStorage.setItem("lastState", value);
    },
    loadSnippet() {
      const model = this.editor.getModel();
      if (localStorage.getItem("lastState")) {
        model.setValue(localStorage.getItem("lastState"));
      }
    }
  }
};
</script>

<style scoped>
.editor {
  height: 450px;
  min-width: 650px;
  position: fixed;
}

.buttons {
  margin-top: 450px !important;
}
</style>
